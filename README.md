# smack-stack-tutorial

DC/OS SMACK Stack Tutorial

A beginner's tutorial for running the SMACK Stack on a Mesosphere's DC/OS cluster. Includes steping through a simple deployment process for:

- Apache Spark
- Spark History Server
- Apache Kafka
- Apache Cassandra
- Apache HDFS

Additionally, this tutorial guides a reader through a simple example of running a Spark job that reads a file from the HDSF service and from a Kafka queue. 

     *** NOTE: This Tutorial is provided for convenience     ***
     *** and is not directly supported by Mesosphere, Inc.   ***

# Tutorial Document

The complete tutorial document can be found in the resources directory in this repo. See:

![Mesosphere-SMACK-Stack-Tutorial.pdf](/resources/Mesosphere-SMACK-Stack-Tutorial.pdf?raw=true "DC/OS SMACK Stack Tutorial")

# Quick Deployment Scripts

If you would like to quickly deploy these components you can use the pre-built startup script named start-smackstack.sh Follow these instructions:

## Step 1. Deploy a DC/OS cluster.

Deploy a DC/OS cluster with at least nine (9) private agent nodes. The SMACK Stack packages start a lot of tasks and many of the tasks (HDFS namenodes and datanodes, for example) have placement constraints that prohibit them from running on the same agent node. Therefore at least 9 private agent nodes are needed. Instructions for deploying DC/OS clusters can be found here:

     https://dcos.io/install/

     https://docs.mesosphere.com/1.10/installing/

## Step 2. Clone this repo on your client computer.

     $ git clone https://github.com/gregpalmr/smack-stack-tutorial

     $ cd smack-stack-tutorial

## Step 3. Start the SMACK Stack Components.

Start the SMACK Stack components with this command:

     $ scripts/start-smackstack.sh

The script will wait for all the components to start and then will recommend a Spark job to run.

## Step 4. Run the Spark Job.

Run the sample Spark job with this command:

     $ scripts/run-sample-spark-hdfs-job.sh

## Step 5. Stop the SMACK Stack Components.

If you would like to stop all the SMACK Stack components, use this command:

     $ scripts/stop-smackstack.sh


