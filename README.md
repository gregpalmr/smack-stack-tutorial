# smack-stack-tutorial

DC/OS SMACK Stack Tutorial

A beginner's tutorial for running the SMACK Stack on a Mesosphere's DC/OS cluster. Includes stepping through a simple deployment process for:

- Apache Spark
- Spark History Server
- Apache Kafka
- Apache Cassandra
- Apache Hadoop HDFS

Additionally, this tutorial guides a reader through a simple example of running a Spark job that reads a file from the HDFS service and from a Kafka queue. 

     *** NOTE: This Tutorial is provided for convenience     ***
     *** and is not directly supported by Mesosphere, Inc.   ***

# Tutorial Document

The complete tutorial document can be found in the resources directory in this repo. See:

![Mesosphere-SMACK-Stack-Tutorial.pdf](/resources/Mesosphere-SMACK-Stack-Tutorial.pdf?raw=true "DC/OS SMACK Stack Tutorial")

# Quick Deployment Scripts - Linux and OS X

If you would like to quickly deploy the SMACK Stack components using the DC/OS Linux or OS X command line interface (CLI), you can use the pre-built startup script named start-smackstack.sh Follow these instructions:

## Linux Step 1. Deploy a DC/OS cluster.

Deploy a DC/OS cluster with at least ten (10) private agent nodes. The SMACK Stack packages start a lot of tasks and many of the tasks (HDFS namenodes and datanodes, for example) have placement constraints that prohibit them from running on the same agent node. Therefore at least 10 private agent nodes are needed. Instructions for deploying DC/OS clusters can be found here:

     https://dcos.io/install/

     https://docs.mesosphere.com/1.10/installing/

## Linux Step 2. Clone this repo on your client computer.

     $ git clone https://github.com/gregpalmr/smack-stack-tutorial

     $ cd smack-stack-tutorial

## Linux Step 3. Start the SMACK Stack Components.

Start the SMACK Stack components with this command:

     $ scripts/start-smackstack.sh <no of public agent nodes>

The script will wait for all the components to start and then will recommend a Spark job to run.

## Linux Step 4. Run the Spark Job.

Run the sample Spark jobs with these commands:

     $ scripts/run-sample-spark-hdfs-job.sh

     $ scripts/run-sample-spark-kafka-job.sh

These spark jobs utilize the Spark-History server and the Spark External Suffle Service in addition to the using the Spark Dispatcher to launch the Spark Driver program and Spark Executors. The Spark submit-args that are used include the following:

     For enabling the use of the External Shuffle Service

          --conf spark.shuffle.service.enabled=true 
          --conf spark.local.dir=/tmp/spark
          --conf spark.dynamicAllocation.enabled=false 

     For enabling the Spark History server

          --conf spark.eventLog.enabled=true 
          --conf spark.eventLog.dir=hdfs://hdfs/history

## Linux Step 5. Stop the SMACK Stack Components.

If you would like to stop all the SMACK Stack components, use this command:

     $ scripts/stop-smackstack.sh


# Quick Deployment Scripts - Windows 10

If you would like to quickly deploy the SMACK Stack components using the DC/OS Windows command line interface (CLI), you can use the pre-built startup script named start-smackstack.bat Follow these instructions:

## Windows Step 1. Deploy a DC/OS cluster.

Deploy a DC/OS cluster with at least ten (10) private agent nodes. The SMACK Stack packages start a lot of tasks and many of the tasks (HDFS namenodes and datanodes, for example) have placement constraints that prohibit them from running on the same agent node. Therefore at least 10 private agent nodes are needed. Instructions for deploying DC/OS clusters can be found here:

     https://dcos.io/install/

     https://docs.mesosphere.com/1.10/installing/

## Windows Step 2. Clone or download this repo on your client computer.

If you have the git tools installed on your Windows computer, use these commands:

     $ git clone https://github.com/gregpalmr/smack-stack-tutorial

     $ cd smack-stack-tutorial

If you do not have the git tools installed on your Windows computer, simply download the repository in the ZIP file format and unzip it to your working directory.  You can download the ZIP file using your Web browser by following these sub-steps:

     a. Point your Web browser to the git repo at: https://github.com/gregpalmr/smack-stack-tutorial

     b. Click on the "Clone or download" button on the right side of the page.

     c. Click on the "Download ZIP" option. If you are prompted to "Open" or "Save" the file, select the "Save" option. 

     d. The file will be saved in your default download directory. 

     e. If using IE, click on the "View downloads" button and then click on the "Open" button. 

     f. If using Chrome, click on the file shown at the bottom of the Web browser window and then click on "Show in Folder". 

     g. When shown in the Explorer window, right-click on the file, select "Extract all" and then specify a destination folder for the extracted files. 

## Windows Step 3. Start the SMACK Stack Components.

Open a Windows command prompt window (cmd.exe) and changed directory to the directory that you extracted the ZIP file contents.

Start the SMACK Stack components with this command:

     $ scripts\start-smackstack.bat

The script will wait for all the components to start and then will recommend a Spark job to run.

## Windows Step 4. Run the Spark Job.

Run the sample Spark jobs with these commands:

     $ scripts\run-sample-spark-hdfs-job.bat

     $ scripts\run-sample-spark-kafka-job.bat

These spark jobs utilize the Spark-History server and the Spark External Suffle Service in addition to the using the Spark Dispatcher to launch the Spark Driver program and Spark Executors. The Spark submit-args that are used include the following:

     For enabling the use of the External Shuffle Service

          --conf spark.shuffle.service.enabled=true 
          --conf spark.local.dir=/tmp/spark
          --conf spark.dynamicAllocation.enabled=false 

     For enabling the Spark History server

          --conf spark.eventLog.enabled=true 
          --conf spark.eventLog.dir=hdfs://hdfs/history

## Windows Step 5. Stop the SMACK Stack Components.

If you would like to stop all the SMACK Stack components, use this command:

     $ scripts\stop-smackstack.bat


