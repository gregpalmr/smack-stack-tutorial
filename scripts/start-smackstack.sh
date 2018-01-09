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
echo " #################################################"
echo " ###   Checking for at least 10 Private Agents ###"
echo " #################################################"
echo

# Get the number of private agent nodes (total nodes - 1)
PRIV_NODE_COUNT=$(dcos node | grep agent | wc -l)
if [ "$PRIV_NODE_COUNT" == "" ]
then
    echo " ERROR: Number of private agent nodes was not found."
    echo " Exiting."
    echo
    exit 1
fi
PRIV_NODE_COUNT=$((PRIV_NODE_COUNT-1))

if [ "$PRIV_NODE_COUNT" -lt 10 ]
then
    echo " ERROR: Number of private agent nodes must be 10 or more."
    echo "        Only showing $PRIV_NODE_COUNT private agent nodes."
    echo " Exiting."
    echo
    exit 1
fi
echo
echo "    DC/OS Agent Node Count is Sufficient."

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
    std_out=$(dcos task log hdfs-setup-commands stdout 2>&1 | grep 'test-data.txt')
    std_err=$(dcos task log hdfs-setup-commands stderr 2>&1 | grep 'test-data.txt')

    if [[ $std_out == *"test-data.txt"* ]] || [[ $std_err == *"File exists"* ]]
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

dcos marathon app add config/spark-history-options.json

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
echo " ###############################################"
echo " ### Starting Spark External Shuffle Service ###"
echo " ###############################################"
echo


# Set the instance count as the number private agent nodes
sed "s/256/$PRIV_NODE_COUNT/" config/spark-shuffle.json > /tmp/spark-shuffle.json

# Start the service
dcos marathon app add /tmp/spark-shuffle.json

echo
echo " Waiting for Spark External Shuffle Service to start. "
while true 
do
    task_status=$(dcos task |grep spark-shuffle | awk '{print $4}' | grep R | wc -l)

    if [ "$task_status" -ne $PRIV_NODE_COUNT ]
    then
        printf "."
    else
        echo " Spark External Shuffle Service is running."
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
echo " #############################################"
echo " ### Starting Kafka Producer and Consumer  ###"
echo " #############################################"
echo
echo
echo " Waiting for Kafka service to start. "
while true 
do
    task_status=$(dcos task |grep 'kafka-0-broker ' | awk '{print $4}')

    if [ "$task_status" != "R" ]
    then
        printf "."
    else
        echo " Kafka service is running."
        break
    fi
    sleep 10
done

dcos kafka topic create my-topic --partitions=3 --replication=3

sleep 2

dcos marathon app add config/kafka-consumer.json

sleep 10

dcos kafka topic producer_test my-topic 100


echo
echo " #############################################################"
echo " ### SMACK Stack start up complete.                        ###"
echo " ### If you would like to run a Spark jobs that read       ###"
echo " ### from the HDFS file system or from a Kafka queue,      ###"
echo " ### run the following commands:                           ###"
echo " #############################################################"
echo

echo "     $ scripts/run-sample-spark-hdfs-job.sh "
echo
echo "     $ scripts/run-sample-spark-kafka-job.sh "

echo


# End of Script
