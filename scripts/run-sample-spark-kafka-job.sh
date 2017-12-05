#!/bin/bash
#
# SCRIPT: run-sample-spark-kafka-job.sh
#

dcos spark run --submit-args='--conf spark.eventLog.enabled=true --conf spark.eventLog.dir=hdfs://hdfs/history --conf Dspark.mesos.coarse=true --conf spark.cores.max=4 --conf spark.executor.memory=1g --driver-cores 1 --driver-memory 1g --class org.apache.spark.examples.streaming.KafkaWordCount  https://downloads.mesosphere.com/spark/assets/spark-examples_2.10-1.4.0-SNAPSHOT.jar mesos://leader.mesos:5050 zk-1.zk,zk-2.zk,zk-3.zk my-consumer-group my-topic 1'

# End of script
