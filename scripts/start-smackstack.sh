#!/bin/bash
#
# SCRIPT: start-smackstack.sh
#

echo
echo " #################################"
echo " ### Verifying DC/OS CLI Setup ###"
echo " #################################"
echo

# Make sure the DC/OS CLI is available
result=$(which dcos 2>&1)
if [[ "$result" == *"no dcos in"* ]]
then
        echo
        echo " ERROR: The DC/OS CLI program is not installed. Please install it."
        echo " Follow the instructions found here: https://docs.mesosphere.com/1.10/cli/install/"
        echo " Exiting."
        echo
        exit 1
fi

# Get DC/OS Master Node URL
MASTER_URL=$(dcos config show core.dcos_url 2>&1)
if [[ $MASTER_URL != *"http"* ]]
then
        echo
        echo " ERROR: The DC/OS Master Node URL is not set."
        echo " Please set it using the 'dcos cluster setup' command."
        echo " Exiting."
        echo
        exit 1
fi

# Check if the CLI is logged in
result=$(dcos node 2>&1)
if [[ "$result" == *"No cluster is attached"* ]]
then
    echo
    echo " ERROR: No cluster is attached. Please use the 'dcos cluster attach' command "
    echo " or use the 'dcos cluster setup' command."
    echo " Exiting."
    echo
    exit 1
fi
if [[ "$result" == *"Authentication failed"* ]]
then
    echo
    echo " ERROR: Not logged in. Please log into the DC/OS cluster with the "
    echo " command 'dcos auth login'"
    echo " Exiting."
    echo
    exit 1
fi
if [[ "$result" == *"is unreachable"* ]]
then
    echo
    echo " ERROR: The DC/OS master node is not reachable. Is core.dcos_url set correctly?"
    echo " Please set it using the 'dcos cluster setup' command."
    echo " Exiting."
    echo
    exit 1

fi

echo
echo "    DC/OS CLI Setup Correctly "
echo

echo
echo " ##############################"
echo " ###   Starting Cassandra   ###"
echo " ##############################"
echo
dcos package install --options=config/cassandra-options.json cassandra --yes

echo
echo " ##############################"
echo " ###    Starting Kafka      ###"
echo " ##############################"
echo
dcos package install --options=config/kafka-options.json kafka --yes

echo
echo " ##############################"
echo " ###      Starting HDFS     ###"
echo " ##############################"
echo
dcos package install --options=config/hdfs-options.json hdfs --yes

# Wait for all HDFS data node task to show status of R for running
echo
echo " Waiting for HDFS service to start. "

while true 
do
    # Get the number of data nodes
    datanode_count=$(dcos task | grep data- | wc -l)

    if [ "$datanode_count" -gt 0 ]
    then
        last_datanode=$(($datanode_count-1))

        task_status=$(dcos task |grep data-${last_datanode}-node | awk '{print $4}')

        if [ "$task_status" != "R" ]
        then
            printf "."
        else
            echo
            echo " HDFS service is running."
            break
        fi
    else
        printf "."
    fi
    sleep 10
done

echo
echo " #################################"
echo " ### Creating HDFS directories ###"
echo " ### and test data             ###"
echo " #################################"
echo

sleep 10

dcos marathon app add config/hdfs-setup-commands.json

echo
echo " Waiting for HDFS setup commands to complete. "
while true 
do
    hdfs_files=$(dcos task log hdfs-setup-commands stdout 2>&1 | grep 'test-data.txt')

    if [[ $hdfs_files == *"test-data.txt"* ]]
    then
        echo " HDFS setup commands completed successfully."
        break
    else
        printf "."
    fi
    sleep 10
done

dcos marathon app remove hdfs-setup-commands

echo
echo " #####################################"
echo " ### Starting Spark History Server ###"
echo " #####################################"
echo

dcos package install spark-history --options=config/spark-history-options.json --yes

echo
echo " Waiting for Spark History server to start. "
while true 
do
    task_status=$(dcos task |grep spark-history | awk '{print $4}')

    if [ "$task_status" != "R" ]
    then
        printf "."
    else
        echo " Spark History server is running."
        break
    fi
    sleep 10
done

echo
echo " ##############################"
echo " ### Starting Spark Service ###"
echo " ##############################"
echo

# Modify the spark options file with the core.dcos_url for this cluster
cat config/spark-options.json | awk -v url="$MASTER_URL" '{gsub(/MASTER_URL/,url)}1' > /tmp/spark-options.json

# Start the spark service
dcos package install spark --options=/tmp/spark-options.json --yes

# Wait for the spark service to get a running status
echo
echo " Waiting for Spark service to start. "
while true 
do
    task_status=$(dcos task |grep 'spark ' | awk '{print $4}')

    if [ "$task_status" != "R" ]
    then
        printf "."
    else
        echo " Spark service is running."
        break
    fi
    sleep 10
done

echo
echo " #############################################################"
echo " ### Smack Stack start up complete.                        ###"
echo " ### If you would like to run a Spark job that reads       ###"
echo " ### from the HDFS file system, run the following command: ###"
echo " #############################################################"
echo

cat sample-spark-job.txt

echo


# End of Script
