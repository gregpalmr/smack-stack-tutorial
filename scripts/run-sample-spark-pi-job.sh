#!/bin/bash
#
# SCRIPT: run-sample-spark-pi-job.sh
#

echo
echo "#############################################"
echo "### Running Spark SaprkPi example.        ###"
echo "#############################################"
echo

dcos spark run --name 'spark' --submit-args='--conf spark.mesos.coarse=true --conf spark.cores.max=4 --conf spark.executor.memory=2g --driver-cores 1 --driver-memory 1g --class org.apache.spark.examples.SparkPi https://downloads.mesosphere.com/spark/assets/spark-examples_2.10-1.4.0-SNAPSHOT.jar 30'

# End of script
