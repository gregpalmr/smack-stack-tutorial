::
::
:: SCRIPT: run-sample-spark-hdfs-job.bat
::

echo -
echo - #############################################
echo - ###  Running Spark HDFSWordCount example. ###
echo - #############################################
echo -

dcos spark run --name="spark" --submit-args="--conf spark.eventLog.enabled=true --conf spark.eventLog.dir=hdfs://hdfs/history --conf spark.mesos.coarse=true --conf spark.cores.max=4 --conf spark.executor.memory=2g --driver-cores 1 --driver-memory 1g --conf spark.shuffle.service.enabled=true --conf spark.dynamicAllocation.enabled=false --conf spark.local.dir=/tmp/spark --class HDFSWordCount https://s3-us-west-2.amazonaws.com/greg-palmer/smack-stack-tutorial/sparkjob-assembly-1.0.jar hdfs:///test-data/test-data.txt"

:: End of script
