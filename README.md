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

## Step 1. Clone this repo on your client computer.

     $ git clone https://github.com/gregpalmr/smack-stack-tutorial

     $ cd smack-stack-tutorial

## Step 2. Start the SMACK Stack Components.

Start the SMACK Stack components with this command:

     $ scripts/start-smackstack.sh

The script will wait for all the components to start and then will recommend a Spark job to run.

## Step 3. Run the Spark Job.

Run the sample Spark job with this command:

     $ scripts/run-sample-spark-hdfs-job.sh

## Step 4. Stop the SMACK Stack Components.

If you would like to stop all the SMACK Stack components, use this command:

     $ scripts/stop-smackstack.sh


