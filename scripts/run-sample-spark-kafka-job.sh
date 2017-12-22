#!/bin/bash
#
# SCRIPT: run-sample-spark-kafka-job.sh
#
#
# Thanks to Arthur Rand, arand@mesosphere.com, for providing the Spark/Kafka JAR file 
#

echo
echo "#############################################"
echo "### Running Spark Kafka Consumer example. ###"
echo "#############################################"
echo

dcos spark run --name="spark" --submit-args='--conf spark.eventLog.enabled=true --conf spark.eventLog.dir=hdfs://hdfs/history --conf spark.mesos.coarse=true --conf spark.cores.max=4 --conf spark.executor.memory=1g --driver-cores 1 --driver-memory 1g --conf spark.shuffle.service.enabled=true --conf spark.dynamicAllocation.enabled=false --conf spark.local.dir=/tmp/spark --class KafkaConsumer https://s3-us-west-2.amazonaws.com/greg-palmer/smack-stack-tutorial/dcos-spark-scala-tests-assembly-0.1-SNAPSHOT.jar broker.kafka.l4lb.thisdcos.directory:9092 my-topic 40 false'

echo
echo " Also running the command to genreate Kafka producer test data in topic my-topic. "
echo " Watch the STDOUT for the Spark Driver task in the DC/OS Service->Spark Web page:"
echo
sleep 20
dcos kafka topic producer_test my-topic 100
dcos kafka topic producer_test my-topic 100
dcos kafka topic producer_test my-topic 100
echo

# End of script
