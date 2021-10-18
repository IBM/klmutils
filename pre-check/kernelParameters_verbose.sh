#!/bin/bash

#
# File Name: kernelParameters.sh
#
# Licensed Materials - Property of IBM
#
# 5724-T60 5608-A91
# (C) Copyright IBM Corp. 2008, 2009  All Rights Reserved
#
# US Government Users Restricted Rights - Use, duplication, or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
#

##############################################################################
# This script will check the system			#
#  if kernel parameters have required values to setup multimaster configuration in Linux OS.
##############################################################################

requiredMSGMNI="false"
requiredSEMMSL="false"
requiredSEMMNS="false"
requiredSEMOPM="false"
requiredSEMMNI="false"
totalPhysicalMemory=0
MSGMNIThreshold=0
SEMMNIThreshold=0
SEMMNSThreshold=0
message=""     
export TMPDIR=/tmp  
OS=`uname`

printusage() {
echo "*************************************************************************
	 Usage:	 ./kernelParameters.sh
	 where
	 kernelParameters script will validate if kernel parameters on your system has required values to configure a Multi-Master cluster.

Note:	 Please ensure to use this script for Linux OS only                               
							
********************************************************************************"
exit 1
}

if [ $# -ne 0 ]; then
        printusage
fi              

checkParameters() {
		MSGMNI=`ipcs -l | grep "max queues system wide" | sed 's/[^0-9]//g'` 
		SEMMSL=`ipcs -l | grep "max semaphores per array" | sed 's/[^0-9]//g'`                               
		SEMMNS=`ipcs -l | grep "max semaphores system wide" | sed 's/[^0-9]//g'`                          
		SEMOPM=`ipcs -l | grep "max ops per semop call" | sed 's/[^0-9]//g'`                          
		SEMMNI=`ipcs -l | grep "max number of arrays" | sed 's/[^0-9]//g'`
		totalPhysicalMemory=($(awk '/MemTotal/ { printf "%.3f \n", $2/1024/1024 }' /proc/meminfo))
}          

#Executing Main
if [ "${OS}" == "Linux" ]
then
	checkParameters
	
	MSGMNIThreshold=($(echo "$totalPhysicalMemory 1024" | awk '{print ($1 * $2)}'))
	SEMMNIThreshold=($(echo "$totalPhysicalMemory 256" | awk '{print ($1 * $2)}'))
	SEMMNSThreshold=($(echo "$SEMMNIThreshold 250" | awk '{print ($1 * $2)}'))
	
	if [[ `echo "$MSGMNI $MSGMNIThreshold" | awk '{print ($1 < $2)}'` == 1 ]]
	then
		message="${message} \n kernel.msgmni "
		requiredMSGMNI="false"
	else
		requiredMSGMNI="true"
	fi
        message="${message} \n kernel.msgmni: $MSGMNI -ge $MSGMNIThreshold ==> $requiredMSGMNI "

	if [ $SEMMSL -lt 250 ]
	then
		message="${message} \n kernel.sem SEMMSL "
		requiredSEMMSL="false"
	else
		requiredSEMMSL="true"
	fi
	message="${message} \n kernel.sem SEMMSL: $SEMMSL -ge 250 ==> $requiredSEMMSL"

	if [[ `echo "$SEMMNS $SEMMNSThreshold" | awk '{print ($1 < $2)}'` == 1 ]]
	then
		message="${message} \n kernel.sem SEMMNS "
		requiredSEMMNS="false"
	else
		requiredSEMMNS="true"
	fi
	message="${message} \n kernel.sem SEMMNS: $SEMMNS -ge $SEMMNSThreshold ==> $requiredSEMMNS"

	if [ $SEMOPM -lt 32 ]
	then
		message="${message} \n kernel.sem SEMOPM "
		requiredSEMOPM="false"
	else
		requiredSEMOPM="true"
	fi
	message="${message} \n kernel.sem SEMOPM: $SEMOPM -ge 32 ==> $requiredSEMOPM" 

	if [[ `echo "$SEMMNI $SEMMNIThreshold" | awk '{print ($1 < $2)}'` == 1 ]]
	then
		message="${message} \n kernel.sem SEMMNI "
		requiredSEMMNI="false"
	else
		requiredSEMMNI="true"
	fi
	message="${message} \n kernel.sem SEMMNI: $SEMMNI -ge $SEMMNIThreshold ==> $requiredSEMMNI"

	if [ "${requiredMSGMNI}" == "true" ] && [ "${requiredSEMMSL}" == "true" ] && [ "${requiredSEMMNS}" == "true" ] && [ "${requiredSEMOPM}" == "true" ] && [ "${requiredSEMMNI}" == "true" ]; then
			echo -e "$message"
			exit 0
	else
			if [ "${silentInstall}" == "true" ]
			then
				echo -e "Warning:Values of the following Db2 kernel parameters do not meet the minimum requirements to configure a Multi-Master cluster on this server: $message \n To configure a Multi-Master cluster, ensure that you set the appropriate values for these parameters. For more information, see the product documentation in the IBM Knowledge Center. "
			else
				echo -e "Warning: Values of the following Db2 kernel parameters do not meet the minimum requirements to configure a Multi-Master cluster on this server: $message \n If you plan to configure a Multi-Master cluster, you must cancel this installation, update the values, and then run the installer again. "
			fi
			exit 1
	fi
else
	printusage
fi
