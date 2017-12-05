#!/bin/bash
#
# SCRIPT: stop-all.sh
#

echo
echo " ### Retrieving core.dcos_url ### "
CORE_DCOS_URL=$(dcos config show core.dcos_url 2>&1)

if [[ $CORE_DCOS_URL == *"http"* ]]
then
    echo "     core.dcos_url found."
else
    echo "     ERROR: core.dcos_url not found. Exiting."
    exit 1
fi

echo
echo " ### Stopping Spark Service"

# Spark Service
dcos package uninstall spark --app-id='spark' --yes

echo
echo " ### Stopping Spark History Server"

# Spark History Server
sleep 2
dcos package uninstall spark-history --app-id='spark-history' --yes


echo
echo " ### Stopping HDFS "

# HDFS 
sleep 2
dcos package uninstall hdfs --app-id='hdfs' --yes

echo
echo " ### Stopping Kafka Consumer "

dcos marathon app remove kafka-consumer

echo
echo " ### Stopping Kafka "

# Kafka 
sleep 2
dcos package uninstall kafka --app-id='kafka' --yes

echo
echo " ### Stopping Cassandra "

# Cassandra 
sleep 2
dcos package uninstall cassandra --app-id='cassandra' --yes

# Zookeeper cleanup
# First, make sure all services are removed

echo
echo " ### Waiting for all tasks to stop "
echo
while true
do
    task_count=$(dcos task | grep -e hdfs -e data- -e name- -e journal- -e cassandra -e node- -e kakfa -e spark | wc -l)

    if [ "$task_count" -eq 0 ]
    then
        # no tasks are running, safe to remove metadata from zk
        break
    else
        printf "."
    fi
    sleep 10
done

echo
echo " ### Removing Metadata in Zookeeper"
dcos marathon app add config/zookeeper-commands.json

# End of Script
