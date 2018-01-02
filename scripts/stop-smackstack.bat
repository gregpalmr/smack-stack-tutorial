::
::
:: SCRIPT: stop-smackstack.bat
::

@ECHO OFF
SETLOCAL ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION


echo -
echo - ### Retrieving core.dcos_url ###
dcos config show core.dcos_url > .cmd.out 2>&1

for /f "delims=" %%a in ('findstr "http" .cmd.out') do @set CORE_DCOS_URL=%%a

if "%CORE_DCOS_URL%"=="" (
        echo - ERROR: core.dcos_url not found. Exiting.
        exit /B 1
	)

echo -     core.dcos_url found.

echo -
echo - ### Stopping Spark Service
echo -
:: Spark Service
dcos package uninstall spark --app-id="spark" --yes

echo -
echo - ### Stopping Spark History Server
echo -
:: Spark History Server

:: Sleep for 2 seconds
timeout /T 2 >nul   
dcos package uninstall spark-history --app-id="spark-history" --yes

echo -
echo - ### Stopping Spark External Shuffle Service
echo -
dcos marathon app remove spark-shuffle 

echo -
echo - ### Stopping HDFS
echo -
:: HDFS 

:: Sleep for 2 seconds
timeout /T 2 >nul   
dcos package uninstall hdfs --app-id="hdfs" --yes

echo -
echo - ### Stopping Kafka Consumer
echo -
dcos marathon app remove kafka-consumer

echo -
echo - ### Stopping Kafka
echo -
:: Kafka 

:: Sleep for 2 seconds
timeout /T 2 >nul   
dcos package uninstall kafka --app-id="kafka" --yes

echo -
echo - ### Stopping Cassandra
echo -
:: Cassandra 

:: Sleep for 2 seconds
timeout /T 2 >nul   
dcos package uninstall cassandra --app-id="cassandra" --yes

:: Zookeeper cleanup
:: First, make sure all services are removed

echo -
echo - ### Waiting for all tasks to stop
echo -

:start-check-tasks-loop

   dcos task | findstr /L "hdfs data name- journal- cassandra node- kafka spark" > .cmd.out | findstr " R " 2>&1
   
   for /f %%C in ('Find /V /C "" ^< .cmd.out') do set TASK_COUNT=%%C
   
   if %TASK_COUNT% GTR 0 (
	     echo .
		 :: Sleep for 10 seconds
		 timeout /T 10 >nul
        goto start-check-tasks-loop
   )

echo -
echo - ### Removing Metadata in Zookeeper

:: Sleep for 5 seconds
timeout /T 5 >nul   
dcos marathon app add config/zookeeper-commands.json

del .cmd.out

:: End of Script
