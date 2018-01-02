::
::
:: SCRIPT: start-smackstack.bat
::

@ECHO OFF
SETLOCAL ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION

echo -
echo - #################################
echo - ### Verifying DC/OS CLI Setup ###
echo - #################################
echo -

:: Make sure the DC/OS CLI is available
where >nul 2>nul dcos
if %ERRORLEVEL% NEQ 0 (
        echo -
        echo - ERROR: The DC/OS CLI program is not installed. Please install it.
		echo - Follow the instructions found here: 
		echo -         https://docs.mesosphere.com/1.10/cli/install/
        echo - Exiting.
        echo -
        exit /B 1
	)

:: Get DC/OS Master Node URL
dcos config show core.dcos_url > .cmd.out 2>&1

for /f "delims=" %%a in ('findstr "http" .cmd.out') do @set MASTER_URL=%%a

if "%MASTER_URL%"=="" (
        echo -
        echo - ERROR: The DC/OS Master Node URL is not set.
        echo - Please set it using the 'dcos cluster setup' command or 
        echo - Exiting.
        echo -
        exit /B 1
	)

:: Check if the CLI is logged in
dcos node > .cmd.out 2>&1

for /f "delims=" %%a in ('findstr "Missing required config parameter" .cmd.out') do @set result=%%a
if not "%result%"=="" (
    echo -
    echo - ERROR: Missing required config parameter: "core.dcos_url". 
	echo - Please run `dcos config set core.dcos_url <value>`.
    echo - Exiting.
    echo -
    exit /B 1
    )
for /f "delims=" %%a in ('findstr "No cluster is attached" .cmd.out') do @set result=%%a
if not "%result%"=="" (
    echo -
    echo - ERROR: No cluster is attached. Please use the 'dcos cluster attach' command
    echo - or use the 'dcos cluster setup' command.
    echo - Exiting.
    echo -
    exit /B 1
    )
for /f "delims=" %%a in ('findstr "Authentication failed" .cmd.out') do @set result=%%a
if not "%result%"=="" (
    echo -
    echo - ERROR: Not logged in. Please log into the DC/OS cluster with the
    echo - command 'dcos auth login'
    echo - Exiting.
    echo -
    exit /B 1
    )
for /f "delims=" %%a in ('findstr "is unreachable" .cmd.out') do @set result=%%a
if not "%result%"=="" (
    echo -
    echo - ERROR: The DC/OS master node is not reachable. Is core.dcos_url set correctly?
    echo - Please set it using the 'dcos cluster setup' command.
    echo - Exiting.
    echo -
    exit /B 1
    )

echo -
echo -    DC/OS CLI Setup Correctly 
echo -

echo -
echo - #################################################
echo - ###   Checking for at least 10 Private Agents ###
echo - #################################################
echo -

:: Get the number of private agent nodes (total nodes - 1)
dcos node | findstr agent > .cmd.out 2>&1
for /f %%C in ('Find /V /C "" ^< .cmd.out') do set PRIV_NODE_COUNT=%%C

if "%PRIV_NODE_COUNT%"=="" (
    echo - ERROR: Number of private agent nodes was not found.
    echo - Exiting.
    echo -
    exit /B 1
    )

set /a PRIV_NODE_COUNT -= 1

if %PRIV_NODE_COUNT% LSS 10 (
    echo - ERROR: Number of private agent nodes must be 10 or more.
    echo -        Only showing %PRIV_NODE_COUNT% private agent nodes.
    echo - Exiting.
    echo -
    exit /B 1
    )
	
echo -
echo -    DC/OS Agent Node Count is Sufficient.

::goto start_test 

echo -
echo - ##############################
echo - ###   Starting Cassandra   ###
echo - ##############################
echo -
dcos package install --options=config/cassandra-options.json cassandra --yes

echo -
echo - ##############################
echo - ###    Starting Kafka      ###
echo - ##############################
echo -
dcos package install --options=config/kafka-options.json kafka --yes

echo -
echo - ##############################
echo - ###      Starting HDFS     ###
echo - ##############################
echo -
dcos package install --options=config/hdfs-options.json hdfs --yes

:: Wait for all HDFS data node task to show status of R for running
echo -
echo - Waiting for HDFS service to start.

:start-hdfs-loop
   :: Sleep for 10 seconds
   timeout /T 10 >nul
   
   ::Get the number of data nodes
   dcos node | findstr data- > .cmd.out 2>&1
   for /f %%C in ('Find /V /C "" ^< .cmd.out') do set datanode_count=%%C

   if "%datanode_count%"=="" (
        echo .
        goto start-hdfs-loop
   )
 
   set /a last_datanode = datanode_count -= 1
   
   :: Get the running status of the last datanode task
   dcos task | findstr data-%last_datanode%-node > .cmd.out 2>&1
   for /f "tokens=4" %%c in ('type .cmd.out') do set task_status=%%c
   
   if "%task_status%" NEQ "R" (
        echo .
        goto start-hdfs-loop
   )
     
echo -
echo - HDFS service is running.

echo -
echo - #################################
echo - ### Creating HDFS directories ###
echo - ### and test data             ###
echo - #################################
echo -

dcos marathon app add config/hdfs-setup-commands.json

echo -
echo - Waiting for HDFS setup commands to complete.

:start-hdfs-cmds-loop 
    
	dcos task log hdfs-setup-commands stdout > .cmd.out 2>&1
	
	for /f "delims=" %%a in ('findstr test-data.txt .cmd.out') do @set hdfs_files=%%a
	
    if "%hdfs_files%" == "" (
	     echo .
		 :: Sleep for 10 seconds
		 timeout /T 10 >nul
	     goto :start-hdfs-cmds-loop
	)
	
echo - HDFS setup commands completed successfully.

dcos marathon app remove hdfs-setup-commands

echo -
echo - #####################################
echo - ### Starting Spark History Server ###
echo - #####################################
echo -

dcos marathon app add config/spark-history-options.json

echo -
echo - Waiting for Spark History server to start.

:start-spark-history-loop

   dcos task | findstr spark-history > .cmd.out 2>&1
   
   for /f "tokens=4" %%c in ('type .cmd.out') do set task_status=%%c
   
   if "%task_status%" NEQ "R" (
	     echo .
		 :: Sleep for 10 seconds
		 timeout /T 10 >nul
        goto start-spark-history-loop
   )

   echo - Spark History server is running.

echo -
echo - ###############################################
echo - ### Starting Spark External Shuffle Service ###
echo - ###############################################
echo -


:: Set the instance count as the number private agent nodes
::sed "s/256/$PRIV_NODE_COUNT/" config/spark-shuffle.json > /tmp/spark-shuffle.json

:: Start the service
dcos marathon app add config/spark-shuffle.json

echo -
echo - Waiting for Spark External Shuffle Service to start. 


:start-spark-external-shuffle-loop

   dcos task | findstr spark-shuffle | findstr " R " > .cmd.out 2>&1
   
   for /f %%C in ('Find /V /C "" ^< .cmd.out') do set SHUFFLE_TASK_COUNT=%%C
   
   if %SHUFFLE_TASK_COUNT% LSS %PRIV_NODE_COUNT% (
   	     echo .
		 :: Sleep for 10 seconds
		 timeout /T 10 >nul
        goto :start-spark-external-shuffle-loop
   )

echo - Spark External Shuffle service is running.

echo -
echo - ##############################
echo - ### Starting Spark Service ###
echo - ##############################
echo -

:: Modify the spark options file with the core.dcos_url for this cluster
(for /f "delims=" %%i in ('findstr "^" "config\spark-options.json"') do (
    set "line=%%i"
    setlocal enabledelayedexpansion
    set "line=!line:MASTER_URL=%MASTER_URL%!"
    echo(!line!
    endlocal
))>".spark-options.json"

:: Start the spark service
dcos package install spark --options=.spark-options.json --yes

:: Wait for the spark service to get a running status
echo -
echo - Waiting for Spark service to start.

:start-spark-service-loop

   dcos task | findstr "spark\." > .cmd.out 2>&1
   
   for /f "tokens=4" %%c in ('type .cmd.out') do set task_status=%%c
   
   if "%task_status%" NEQ "R" (
	     echo .
		 :: Sleep for 10 seconds
		 timeout /T 10 >nul
        goto start-spark-service-loop
   )

echo - Spark Service is running.

echo -
echo - #############################################
echo - ### Starting Kafka Producer and Consumer  ###
echo - #############################################
echo -
echo -
echo - Checking if Kafka service is started.

:start-check-kafka-loop

   dcos task | findstr "kafka-0-broker" > .cmd.out 2>&1
   
   for /f "tokens=4" %%c in ('type .cmd.out') do set task_status=%%c
   
   if "%task_status%" NEQ "R" (
	     echo .
		 :: Sleep for 10 seconds
		 timeout /T 10 >nul
        goto start-check-kafka-loop
   )

echo - Kafka service is running.

dcos kafka topic create my-topic --partitions=3 --replication=3

:: Sleep for 2 seconds
timeout /T 2 >nul

dcos marathon app add config/kafka-consumer.json

:: Sleep for 10 seconds
timeout /T 10 >nul

dcos kafka topic producer_test my-topic 100

::start_test  

echo -
echo - #############################################################
echo - ### SMACK Stack start up complete.                        ###
echo - ### If you would like to run a Spark jobs that read       ###
echo - ### from the HDFS file system or from a Kafka queue,      ###
echo - ### run the following commands:                           ###
echo - #############################################################
echo -

echo -     $ scripts/run-sample-spark-hdfs-job.sh
echo -
echo -     $ scripts/run-sample-spark-kafka-job.sh

echo -

del .cmd.out
del .spark-options.json

:: End of Script
