#!/bin/bash
#
# SCRIPT:	schedule-chronos-spark-job.sh
#
# USAGE:	./schedule-spark-job.sh [--verbose] \
#					[--schedule=hourly|daily|weekly|monthly|<custom spec>] \
#					[--owner-email=<email>] \
#					[--job-name=<job name>] \
#					[--hdfs] \
#					[--history-server] \
#					[--shuffle-service] \
#                   [--spark-conf=<spark conf options>] \
#					--dcos-master-ip \
#					--dcos-userid=<myuser> --dcos-password=<mypassword> \
#					<class name> <jar file> [<class args>]
# 
#
# HISTORY:	4/25/2016   - greg.palmer@mesosphere.com - Initial Version
#          	10/25/2016  - greg.palmer@mesosphere.com - Removed DC/OS CLI Requirement
#		10/28/2016  - greg.palmer@mesosphere.com - Cleaned up code, tested
#		10/31/2016  - greg.palmer@mesosphere.com - Added hdfs integration
#       1/8/2017    - greg.palmer@mesosphere.com - Added history-server and shuffle-service optinos
#

#
# FUNCTION usage()
#
function usage {
cat<<EOF

        Usage: ./schedule-spark-job.sh  [--verbose] 
                    [--schedule=hourly|daily|weekly|monthly|<custom spec>]
                    [--owner-email=<email>] 
                    [--job-name=<job name>] 
                    [--hdfs] 
                    [--history-server] 
                    [--shuffle-service] 
                    [--spark-conf=<spark conf options>]
                    --dcos-master-ip=<ip address> 
                    --dcos-userid=<myuser> --dcos-password=<mypassword>
                    <class name> <jar file url> ["<class args>"]

		--schedule	Schedule the Spark job at specific times, or specify a custom
				schedule using the format: R1/2016-04-25T23:30:51Z/PT1M (see 
				http://en.wikipedia.org/wiki/ISO_8601).
				The default will be now, one time.
				[NOTE: Only <custom spec> is support at present]
		--owner-email	Email address of the owner
		--job-name	The job name to use in Chronos (defaults to "Spark Job via Chronos")
		--hdfs		Include setup for integrating the default DC/OS HDFS service
				(will also be included if an hdfs:// class arg is specified)
		--history-server   Enable the Spark History Server (Requires HDFS)
		--shuffle-service  Enable the external Spark shuffle service integration
		                          (The external shuffle service must be started separately)
		--spark-conf      The Spark conf settings to be passed to the Spark Dispatcher
		--dcos-master-ip  The IP Address of the leading Mesos master node
		--dcos-userid     The DC/OS user to authenticate
		--dcos-password   The DC/OS user's password
	
        
        Examples:     ./schedule-spark-job.sh \\
                        --dcos-master-ip=35.160.166.141 \\
                        --dcos-userid=bootstrapuser --dcos-password=deleteme \\
                        --spark-conf="--executor-memory=2g --conf spark.cores.max=4" \\
                        org.apache.spark.examples.SparkPi \\
                        http://downloads.mesosphere.com/spark/assets/spark-examples_2.10-1.4.0-SNAPSHOT.jar "30"

                      ./schedule-spark-job.sh \\
                        --dcos-master-ip=35.160.166.141 \\
                        --dcos-userid=bootstrapuser --dcos-password=deleteme \\
                        --hdfs \\
                        org.apache.spark.examples.SparkPi \\
                        http://downloads.mesosphere.com/spark/assets/spark-examples_2.10-1.4.0-SNAPSHOT.jar "30 arg2 arg3"

                      ./schedule-spark-job.sh \\
                        --dcos-master-ip=35.160.166.141 \\
                        --dcos-userid=bootstrapuser --dcos-password=deleteme \\
                        --hdfs \\
                        --history-server \\
                        --schedule="R1//P100Y" \\
                        --job-name=myjob1 --owner-email=jsmith@mycompany.com \\
                        org.apache.spark.examples.SparkPi \\
                        http://downloads.mesosphere.com/spark/assets/spark-examples_2.10-1.4.0-SNAPSHOT.jar "30 arg2 arg3"
EOF

        exit 0;
}

### MAIN ###

# Set script argument  defaults
#schedule_spec="R1/$(date +%Y-%m-%d)T$(date -v +1M +%H:%M:%S)Z/PT1M"
schedule_spec="R0//P100Y" # run it now, and only one time
owner_email=""
owner_email="Unknown_Owner"
tstamp=$(date +"%Y-%m-%d_%H-%M-%S_%s")
job_name="Spark-Job-via-Chronos-${tstamp}"
user_spark_conf=""

# Parse the arguments...
#
if [ "$#" -lt 5 ]; then
	if [ "$1" == "--help" ] || [ "$1" == "-h" ]
	then
		usage
		exit 0;
	fi

       echo
       echo "This script requires at least 5 parameters."
       usage
       exit 1;

elif [ "$#" -gt 5 ]; then

	while [[ $# > 0 ]] ; do

		if [[ "$1" == "--dcos-master-ip"* ]]; then
			dcos_master_ip=$(echo $1 | cut -d '=' -f2)
		elif [[ "$1" == "--dcos-userid"* ]]; then
			dcos_userid=$(echo $1 | cut -d '=' -f2)
		elif [[ "$1" == "--dcos-password"* ]]; then
			dcos_password=$(echo $1 | cut -d '=' -f2)
		elif [[ "$1" == "--verbose" ]]; then
			verbose=true	
		elif [[ "$1" == "--owner-email"* ]]; then
			owner_email=$(echo $1 | cut -d '=' -f2)
		elif [[ "$1" == "--job-name="* ]]; then
			job_name=$(echo $1 | sed 's/--job-name=//')
		elif [[ "$1" == "--hdfs"* ]]; then
			hdfs_support_requested="true"
		elif [[ "$1" == "--history-server"* ]]; then
			history_server_requested="true"
		elif [[ "$1" == "--shuffle-service"* ]]; then
			shuffle_service_requested="true"
		elif [[ "$1" == "--spark-conf="* ]]; then
			user_spark_conf=$(echo $1 | sed 's/--spark-conf=//')
		elif [[ "$1" == "--schedule="* ]]; then
			schedule=$(echo $1 | sed 's/--schedule=//' )
			if [ "$schedule" == "hourly" ]; then
				schedule_spec=""
			elif [ "$schedule" == "daily" ]; then 
				schedule_spec=""
			elif [ "$schedule" == "weekly" ]; then
				schedule_spec=""
			elif [ "$schedule" == "monthly" ]; then
				schedule_spec=""
			else
				# TODO: validate custom schedule spec: i.e. "R1/2016-04-25T23:30:51Z/PT1M"
				schedule_spec="$schedule"
			fi
		else
			# Get the last two or three arguments which must be the 
			# class name and the JAR file URI
			# TODO: check classname and jar file format
			class_name="$1"
			shift
			jar_file_url="$1"
			shift
			class_args="$1"

		fi
		shift
	done
fi

#
# Check if the Chronos service is running
#
task_status=$(dcos task chronos | grep chronos |  awk '{print $4}')

if [ "$task_status" != "R" ]
then
    echo
    echo " ERROR: The Chronos service is not running. Please start the service before running this script."
    echo
    echo "        Use this command:  dcos package install --yes --package-version=2.5.1 chronos "
    echo
    echo "        Exiting."
    exit 1
fi

#
# Make sure this is version 2.5.x of Chronos
#
version_num=$(dcos package describe chronos | grep version\":)

if [[ "$version_num" != *"2.5"* ]]
then
    echo
    echo " ERROR: The Chronos service is not version 2.5.x. Please start the service before running this script."
    echo
    echo "        Use this command:  dcos package install --yes --package-version=2.5.1 chronos "
    echo
    echo "        Exiting."
    exit 1
fi

###

# Remove spaces in job_name
job_name=$(echo $job_name | sed 's/ /-/g')

# Display the supplied arguments
	echo
	echo " Using script parameters:"
	echo "      dcos_master_ip      $dcos_master_ip"
	echo "      dcos_userid         $dcos_userid"
	echo "      dcos_password       $dcos_password"
	echo "      schedule_spec:	$schedule_spec"
	echo "      owner_email: 	$owner_email"
	echo "      job_name:   	$job_name"
	echo "      spark_conf:   	$user_spark_conf"
	echo "      class_name: 	$class_name"
	echo "      jar_file_url:   	$jar_file_url"
	echo "      class_args: 	$class_args"
	echo

errors=""
if [ "$dcos_master_ip" == "" ]
then
	errors=" $errors --dcos-master-ip"
fi
if [ "$dcos_userid" == "" ]
then
	errors=" $errors --dcos-userid"
fi
if [ "$dcos_password" == "" ]
then
	errors=" $errors --dcos-password"
fi

# abort if jar file is not specified
if [ "$jar_file_url" == "" ]
then
	errors=" $errors <jar file> "
fi


if [ "$errors" != "" ]
then
	echo
	echo " ERROR, the following arguments must be supplied: "
	echo 
	echo "        $errors "
	echo
	usage
	exit 1
fi

jar_file="`basename ${jar_file_url}`"

dcos_master_url="http://${dcos_master_ip}"

if [ "$verbose" == true ]; then
	echo
	echo "Using dcos_master_url=${dcos_master_url}"
	echo
fi

#
# Get a DC/OS Auth Token
#
curl_cmd="curl -s --data '{\"uid\":\"{dcos_userid}\", \"password\":\"{dcos_password}\"}' --header \"Content-Type:application/json\" ${dcos_master_url}/acs/api/v1/auth/login"
curl_cmd=$(echo $curl_cmd | sed "s/{dcos_userid}/${dcos_userid}/")
curl_cmd=$(echo $curl_cmd | sed "s/{dcos_password}/${dcos_password}/")

if [ "$verbose" == true ]; then
	echo
	echo " Requesting Auth Token with: ${curl_cmd} "
	echo
fi

dcos_auth_token=$(eval ${curl_cmd})

if [[ "$dcos_auth_token" == *"Unauthorized"* ]]
then
	echo
	echo " ERROR: Unable to access DC/OS REST API with supplied dcos_userid and dcos_password"
	echo
	echo "        Exiting."
	exit 1
fi

if [[ "$dcos_auth_token" == *"Bad Request"* ]]
then
	error_message=$(echo ${dcos_auth_token} | grep -i description)
	echo
	echo " ERROR: Auth Token not retrieved correctly."
	echo "        Message is: ${error_message}"
	echo
	echo "        Exiting."
	exit 1
fi

# Strip off the double quote chars and the bracket char
dcos_auth_token=$(echo ${dcos_auth_token} | grep token | cut -d ':' -f 2 | sed -e 's/ //g' -e 's/"//g' -e 's/}//g')

if [ "$verbose" == true ]; then
	echo
	echo " Using DC/OS ACS Token: \"$dcos_auth_token\" "
	echo
fi

#
# Get the Spark Service's port number
#
# Use ... /mesos_dns/v1/services/_spark._tcp.marathon.mesos


#
# If caller supplied an hdfs URI in the class args, then include HDFS setup as well
#
if [[ "$class_args" == *"hdfs:"* ]] || [ "$hdfs_support_requested" == "true" ] || [ "$history_server_requested" == "true" ]
then    
	hdfs_config_uri=",\"http://api.hdfs.marathon.l4lb.thisdcos.directory/v1/endpoints/hdfs-site.xml\", \"http://api.hdfs.marathon.l4lb.thisdcos.directory/v1/endpoints/core-site.xml\""
fi      

#
# Setup the Spark conf arguments
#
spark_conf_args=" --conf spark.mesos.executor.docker.image=mesosphere/spark:1.0.9-2.1.0-1-hadoop-2.6 "

if [ "$shuffle_service_requested" == "true" ]
then
    spark_conf_args="$spark_conf_args --conf spark.shuffle.service.enabled=true --conf spark.local.dir=/tmp/spark"
fi

if [ "$history_server_requested" == "true" ]
then
    spark_conf_args="$spark_conf_args --conf spark.eventLog.enabled=true --conf spark.eventLog.dir=hdfs://hdfs/history"
fi

if [ "$user_spark_conf" != "" ]
then
    spark_conf_args="$spark_conf_args $user_spark_conf"
fi


#
# Issue the Chronos job submission request
#

spark_ui="${dcos_master_url}/service/spark/ui"

#"schedule": "R1/2016-04-25T23:30:51Z/PT1M",

cat >.chronos.json<<EOF
{
  "name": "${job_name}",
  "schedule": "${schedule_spec}",
  "epsilon": "PT10S",
  "command": "export DEBIAN_FRONTEND=noninteractive && apt-get update && apt-get -y install dnsutils && dispatcher_port=\$(dig _spark._tcp.marathon.slave.mesos. SRV | grep ^_spark._tcp.marathon.slave.mesos. | awk '{print \$7}' | sort | head -n 1) && echo \"### Using Mesos Master: mesos://spark.marathon.slave.mesos:\${dispatcher_port}\" && /opt/spark/dist/bin/spark-submit --master mesos://spark.marathon.slave.mesos:\${dispatcher_port}  --deploy-mode cluster --verbose ${spark_conf_args} --class ${class_name} ${jar_file_url} ${class_args} ",
  "owner": "${owner_email}",
  "async": false,
  "container": {
    "type": "DOCKER",
    "image": "mesosphere/spark:1.0.9-2.1.0-1-hadoop-2.6"
  },
    "cpus": "1.0",
    "mem": "1024",
    "uris": [
	 "${jar_file_url}" ${hdfs_config_uri} 
     ]
}
EOF

if [ "$verbose" == true ]; then
	echo
	echo " Using JSON file: chronos.json"
	echo
	echo
	cat .chronos.json
fi

chronos_url="${dcos_master_url}/service/chronos/scheduler/iso8601"

response=$(curl -s -i -L --cookie "dcos-acs-auth-cookie=${dcos_auth_token}" --header "Content-Type: application/json" -X POST -d"@.chronos.json" $chronos_url)

rm -f .chronos.json 

if [[ "$response" == *"500 Internal Server Error"* ]]; then
	echo
	echo " ERROR: 500 Internal Server Error when calling Chronos"
	echo " Please make sure Chronos is installed on the DC/OS cluster."
	echo
	exit 1;
elif [[ "$response" == *"Unauthorized"* ]]; then
	echo
	echo " ERROR: Unauthorized error while sending request to Chronos service at"
	echo "        $chronos_url"
	echo
	exit 1;	
fi

echo
echo " Spark job \"${job_name}\" successfully submitted via Chronos"
echo
echo " Go to ${dcos_master_url}/service/chronos to see your new job"
echo

echo 
echo " To run your job manually, use these REST API commands:"
echo
echo   dcos_auth_token=\$\(curl -s --data \'{\"uid\":\"${dcos_userid}\", \"password\":\"${dcos_password}\"}\' --header \"Content-Type:application/json\" ${dcos_master_url}/acs/api/v1/auth/login\)
echo
echo   # Strip off the double quote chars and the bracket char
echo   dcos_auth_token=\$\(echo \${dcos_auth_token} \| grep token \| cut -d \':\' -f 2 \| sed -e \'s/ //g\' -e \'s/\"//g\' -e \'s/\}//g\'\)
echo
echo curl -isL --cookie \"dcos-acs-auth-cookie=\${dcos_auth_token}\" -X PUT ${dcos_master_url}/service/chronos/scheduler/job/${job_name}?arguments=-myflag1
echo

# end of script
