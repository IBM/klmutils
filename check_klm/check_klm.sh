#!/bin/bash

################################################################################
# The MIT License (MIT)                                                        #
#                                                                              #
# Copyright (c) 2021 Daniel Wendler                          				   #
#                                                                              #
# Permission is hereby granted, free of charge, to any person obtaining a copy #
# of this software and associated documentation files (the "Software"), to deal#
# in the Software without restriction, including without limitation the rights #
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell    #
# copies of the Software, and to permit persons to whom the Software is        #
# furnished to do so, subject to the following conditions:                     #
#                                                                              #
# The above copyright notice and this permission notice shall be included in   #
# all copies or substantial portions of the Software.                          #
#                                                                              #
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR   #
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,     #
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE  #
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER       #
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,#
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE#
# SOFTWARE.                                                                    #
################################################################################


################################################################################
# Name:		IBM Security Guardium Key Lifecycle Manager NRPE plugin            #
#                                                                              #
# Author: 	Daniel Wendler - daniel(dot)wendler(at)de.ibm.com                  #
#                                                                              #
# Contributor:	                                                               #
#                                                                              #
TOOL_VERSION="0.57"                                                       
#                                                                              #
# Dependencies:	                                                               #
#   - Python, lsof, curl                                                       #
#                                                                              #
# Github Repository:                                                           #
# https://github.com/dwendler/klmutils moved to                                #
#                                                                              #
# https://github.com/IBM/klmutils                                              #
#                                                                              # 
################################################################################

################################################################################
# This bash script checks various aspects of an IBM Security Guardium Key      #
# Lifecycle Manager instances.                                                 #
# It verifies the state of middleware components such as WebSphere Application #
# server, the DB2 instance and if backup needs to be taken because new         # 
# cryptografic objects have been added to the configuration                    #
#                                                                              #
# Typically, it would be run on all KLM instances locally.                     #
# The script can be run locally or can be integrated into Nagios or Icinga.    #
#                                                                              #
# The actual code is managed in the following Git repository - please use the  #
# Issue Tracker to ask questions, report problems or request enhancements. The #
# repository also contains examples.                                           #

# Disclaimer: This sample is provided 'as is', without any warranty or support.#
# It is provided solely for demonstrative purposes - the end user must test and#
# modify this sample to suit his or her particular environment. This code is   #
# provided for your convenience, only - though being tested, there's no        #
# guarantee that it doesn't seriously break things in your environment! If you #
# decide to run it, you do so on your own risk!                                #
################################################################################



# ideally a definition file is provided for each KLM version
# SKLM 3.1: "klm_v31.def"
# SKLM 4.0: "klm_v40.def"
# GKLM 4.1: "klm_v41.def"

DEF_FILE_NAME="klm_v40.def"


# include the file with the variable / values for the desired GKLM / SKLM version
if [ -f $(dirname "$0")/${DEF_FILE_NAME} ];
then 
   . $(dirname "$0")/${DEF_FILE_NAME}
else
   printf "\n\n config file $DEF_FILE_NAME not found, exiting\n\n"
   exit 2
fi


# define REST API port and endpoint. Note that only SKLM 4.0 supports this query
REST_API_ADDRESS="localhost:9443"
REST_API_ENDPOINT_HEALTH="/SKLM/rest/v1/health"


# define path of external tools. lsof may be located under /usr/bin or /usr/sbin
CURL_TOOL="/usr/bin/curl"
PYTHON_TOOL="/usr/bin/python"
PS_TOOL="/usr/bin/ps"
LSOF_TOOL="/usr/sbin/lsof"
WSADMIN_TOOL="/opt/IBM/WebSphere/AppServer/bin/wsadmin.sh"


# define thresholds if free space before evaluating the free space as warning / error, value in GB
FILESYSTEM_FREE_GB_WARN=4    # less than ~ GB free space triggers warnings, in GB, e.g. 4 = 4GB
FILESYSTEM_FREE_GB_ERROR=1   # less than ~ GB free space triggers error, in GB, e.g. 1 = 1GB
exit_rc=0


# custom println function
function print_line
{
   callerFunctionName=${FUNCNAME[1]}
   severity=-1
   severityTxt="undef"
   
   if (( $1 == 0 )); then severityTxt="OK"; fi
   if (( $1 == 1 )); then severityTxt="WARNING"; fi
   if (( $1 == 2 )); then severityTxt="ERROR"; fi
 
   # build message text from function parameters, starting with the second parameter until end of array
   messageTxt=${@:2}
   printf "%-8s %-20s %s\n" $severityTxt $callerFunctionName "$messageTxt"

}

# help text
function error_usage
{
  HELP="\n\n
   IBM Security Guardium Key Lifecycle Manager NRPE plugin, version $TOOL_VERSION (MIT licence)\n
   \n
   usage: \t$0 [ -a | -b | -f | -l | -p | -r | -h ]\n
   \n
   syntax:\n
   \t	-a	\t--> Run ALL checks, identical to no parameter\n
   \t	-b	\t--> Verify if BACKUP is needed\n
   \t   -f  \t--> Verify FILESYSTEM usage\n
   \t   -l  \t--> Verify TCP port LISTERNER states\n
   \t	-p  \t--> Verify that required PROCESSES (WAS, DB2) are running\n
   \t	-r  \t--> check REST API for health status (only KLM 4.0\n
   \t	-h	\t--> Print This Help Screen\n
  "
  echo -e $HELP

}


function check_isBackupNeeded
{
    local func_rc=0
   
    if [ ! -f $WSADMIN_TOOL ]; then
     print_line 1 "wsadmin.sh utility not found under: $WSADMIN_TOOL"
     func_rc=2
     return $func_rc
   fi
	
   
    if [[ (-v KLM_MONITOR_USERNAME ) && ( -v KLM_MONITOR_USERCRED) ]];
    then
  	   cmd_msg=`$WSADMIN_TOOL -username $KLM_MONITOR_USERNAME -password $KLM_MONITOR_USERCRED -lang jython -c '"print AdminTask.tklmBackupIsNeeded()"'`
       cmd_rc=$?
       cmd2_msg=`printf "$cmd_msg" | grep -e CTGKM0002E -e CTGKM1304I -e ADMN0022E -e CTGKM1305I -e WASX7246E`
       cmd2_rc=$?
 	  if (( $cmd_rc !=0 )); then
 	    print_line 2 "$cmd2_msg"
 		func_rc=2
 		return 2
 	  else
 	    if [[ $cmd2_msg =~ "CTGKM1304I" ]]; then
 	       print_line 0 "$cmd2_msg"
 		elif [[ $cmd2_msg =~ "CTGKM1305I" ]]; then
 		   print_line 1 "$cmd2_msg"
		   if (( $func_rc < 1 )); then func_rc=1; fi
		   return $func_rc
 		else 
 		   print_line 2 "$cmd2_msg"
		   func_rc=2
		   return $func_rc
 		fi
 	  fi
 	  
    else
      print_line 1 "monitor user credentials not defined"
 	  if (( $func_rc < 1 )); then func_rc=1; fi
    fi
    
    return $func_rc
}

function check_filesystems
{
   func_rc=0

   # converting to KB because df by default displays KB and not bytes
   FILESYSTEM_FREE_KB_WARN=$(( $FILESYSTEM_FREE_GB_WARN * 1024 * 1024 ))
   FILESYSTEM_FREE_KB_ERROR=$(( $FILESYSTEM_FREE_GB_ERROR * 1024 * 1024 ))


   filesystemList=( "/opt/IBM/WebSphere" "/tmp"  )
   #filesystemList+=("/boot")  # only for testing of error code level

   #note: missing $ below is not an error, evaluating if variable is set... 
   if [[ -v DB2_INSTANCE_HOME ]];
   then
      filesystemList+=($DB2_INSTANCE_HOME)
   fi

   for filesystem in ${filesystemList[@]}
   do
      cmd_msg=`df --output=avail $filesystem 2> /dev/null` # | awk 'NR==2 {print}' `
      cmd_rc=$?
      if (( $cmd_rc == 0));
      then 
         cmd_msg=`printf "$cmd_msg" | awk 'NR==2 {print}'`
         cmd_rc=$?
		 freeSpaceGB=$(($cmd_msg / 1024 / 1024))
         if (( $cmd_msg < $FILESYSTEM_FREE_KB_ERROR)) ;
         then 
             print_line 2 "filesystem $filesystem has less than $FILESYSTEM_FREE_GB_ERROR GB free space: $freeSpaceGB GB"
             if (( $func_rc < 2 )); then func_rc=2; fi

         elif (( $cmd_msg < $FILESYSTEM_FREE_KB_WARN)) ;
         then
	     print_line 1 "filesystem $filesystem has less than $FILESYSTEM_FREE_GB_WARN GB free space: $freeSpaceGB GB"
             if (( $func_rc < 1 )); then func_rc=1; fi
         elif (( $cmd_msg > $FILESYSTEM_FREE_KB_WARN)) ;
         then
	     print_line 0 "filesystem $filesystem has more than $FILESYSTEM_FREE_GB_WARN GB free space: $freeSpaceGB GB"
         fi
      else
          print_line 1 "filesystem $filesystem can not be evaluated - df error"
          if (( $func_rc < 1 )); then func_rc=1; fi
      fi

   done
   return $func_rc

}


function check_processes
{
   local func_rc=0
   if [ ! -f $PS_TOOL ]; then
     print_line 1 "ps utility not found under: $PS_TOOL"
     func_rc=2
     return 2
   fi

   # check for WebSphere Application server process
   cmd_msg=`ps -aef | grep com.ibm.ws.runtime.WsServer | grep -v grep`
   cmd_rc=$?
   if (( $cmd_rc !=0 )); then
      print_line 2 "WebSphere Application server PID: no process detected"
      func_rc=2
   else
      was_pid=`printf "$cmd_msg" | awk '{ print $2 }'`
      print_line 0 "WebSphere Application server PID: $was_pid"
   fi
 

   # check for GKLM/SKLM agent (required for multi master, not for master clone
   
   if [ $IS_MULTIMASTER = true ]; then

      cmd_msg=`ps -aef | grep com.ibm.sklm.agent.SKLMAgent | grep -v grep
`     cmd_rc=$?

      if (( $cmd_rc !=0 )); then
         print_line 2 "GKLM Agent process PID: no process detected"
         func_rc=2
      else
         agent_pid=`printf "$cmd_msg" | awk '{ print $2 }'`
         print_line 0 "GKLM Agent process PID: $agent_pid"
      fi
   fi

   # check for DB2 processes
      cmd_msg=`ps -aef | grep db2wdog | grep -v grep`
      cmd_rc=$?

   if (( $cmd_rc !=0 )); then
      print_line 2 "DB2 database watchdog PID: no process detected"
      func_rc=2
   else
      db2_pid=`printf "$cmd_msg" | awk '{ print $2 }'`
      print_line 0 "DB2 database watchdog PID: $db2_pid"
   fi


   return $func_rc 

}

function lsof_helper
{
   # returns: 0 if no port listener detected due to failure or port is not listening, note: return val needs to be positive integer
   #            rc=0 is used to indicate a problem here!!!
   #          Portnumber if > 0

   local func_rc=0
   portNumber=$1
   command="lsof -Pn -i:$portNumber -sTCP:LISTEN 2> /dev/null | grep -v COMMAND | awk '{ printf \$9 } ' 2> /dev/null | sed -e 's/.*://g' 2> /dev/null"
   cmd_msg=`eval $command`
   if [ -z $cmd_msg ]; then cmd_msg=0; fi

   if (( $portNumber == $cmd_msg )); then 
      echo $cmd_msg
      return 0
   else 
      echo -1
      return 2
   fi
}

function check_ports
{
   local func_rc=0
   if [ ! -f $LSOF_TOOL ]; then
      print_line 1 "lsof utility not found under: $LSOF_TOOL"
      func_rc=1
      return $func_rc
   fi

   # check WAS port
   port=$WAS_HTTPS_PORT
   msgTxt="Websphere HTTPS port $port "
   cmd_msg=$(lsof_helper $port)
   cmd_rc=$? 
   if (( $cmd_rc == 0 )); then
      print_line 0 $msgTxt "OK"
   else
      print_line 2 $msgTxt "FAILED"
      func_rc=2
   fi


   # check KLM ports

   port=$KLM_SSL_PORT
   cmd_msg=$(lsof_helper $port)
   cmd_rc=$?
   msgTxt="GKLM SSL port $port "
   if (( $cmd_rc == 0 )); then
      print_line 0 $msgTxt "OK"
   else
      print_line 2 $msgTxt "FAILED"
      func_rc=2
   fi

   port=$KLM_IPP_PORT
   msgTxt="GKLM IPP port $port "
   cmd_msg=$(lsof_helper $port)
   cmd_rc=$?
   if (( $cmd_rc == 0 )); then
      print_line 0 $msgTxt "OK"
   else
      print_line 2 $msgTxt "FAILED"
      func_rc=2
   fi

   port=$KLM_KMIP_PORT
   msgTxt="GKLM KMIP port $port "
   cmd_msg=$(lsof_helper $port)
   cmd_rc=$?
   if (( $cmd_rc == 0 )); then
      print_line 0 $msgTxt "OK"
   else
      print_line 2 $msgTxt "FAILED"
      func_rc=2
   fi


   port=$KLM_HTTPS_PORT
   msgTxt="GKLM HTTPS GUI port $port "
   cmd_msg=$(lsof_helper $port)
   cmd_rc=$?
   if (( $cmd_rc == 0 )); then
      print_line 0 $msgTxt "OK"
   else
      print_line 2 $msgTxt "FAILED"
      func_rc=2
   fi

   
   #if multi-master then check for GKLM agent port
   if [ $IS_MULTIMASTER = true ]; then
      port=$KLM_AGENT_PORT
      msgTxt="GKLM agent port $port for multi-master  "
      cmd_msg=$(lsof_helper $port)
      cmd_rc=$?
      if (( $cmd_rc == 0 )); then
         print_line 0 $msgTxt "OK"
      else
         print_line 2 $msgTxt "FAILED"
         func_rc=2
      fi

   fi
   

   # check DB2 ports
   #if multi-master then check for GKLM agent port
   if [ $IS_MULTIMASTER = true ]; then
       port=$DB2_HADR_PORT
       msgTxt="DB2 HADR port $port for multi-master "
       cmd_msg=$(lsof_helper $port)
       cmd_rc=$?
       if (( $cmd_rc == 0 )); then
          print_line 0 $msgTxt "OK"
       else
          print_line 2 $msgTxt "FAILED"
          func_rc=2
       fi
   fi


   port=$DB2_PORT
   msgTxt="DB2 default port $port "
   cmd_msg=$(lsof_helper $port)
   cmd_rc=$?
   if (( $cmd_rc == 0 )); then
      print_line 0 $msgTxt "OK"
   else
      print_line 2 $msgTxt "FAILED"
      func_rc=2
   fi



   # check replication related ports

   if [ $IS_REPLICATION = true ]; then
      #check both, master and clone ports. ideally exactly one port is up listening
      replicationPortCount=0

      port=$REPLICATION_MASTER_PORT
      msgTxt="Replication port $port (role master) "
      cmd_msg=$(lsof_helper $port)
      cmd_rc=$?
      if (( $cmd_rc == 0 )); then
         replicationPortCount=$((replicationPortCount + 1))
         print_line 0 $msgTxt "OK"
      fi

      port=$REPLICATION_CLONE_PORT
      msgTxt="Replication port $port (role clone "
      cmd_msg=$(lsof_helper $port)
      cmd_rc=$?
      if (( $cmd_rc == 0 )); then
	 replicationPortCount=$((replicationPortCount + 1))
         print_line 0 $msgTxt "OK"
      fi

      if (( $replicationPortCount != 1 )); then
	     print_line 1 "exactly one Replication port should be listening (master: $REPLICATION_MASTER_PORT, clone: $REPLICATION_CLONE_PORT)"
         if (( $func_rc < 1 )); then func_rc=1; fi

      fi


   fi

   return $func_rc

}

function check_api_status
{
   local func_rc=0

   if [ ! -f $CURL_TOOL ]; then 
      func_rc=1
      print_line 1 "curl tool not found under: $CURL_TOOL"
   fi
  

   if [ ! -f $PYTHON_TOOL ]; then 
      func_rc=1
      print_line 1 "python tool not found under: $CURL_TOOL"
   fi

   if (( $KLM_VERSION < 40 )); then
      func_rc=0
      print_line 0 "REST API endpoint $REST_API_ENDPOINT_HEALTH is not supported on the queried version: ${KLM_VERSION},  endpoint only available in SKLM 4.0"
      return $func_rc
   fi
   
   if (( $KLM_VERSION > 40 )); then
      func_rc=0
      print_line 0 "REST API endpoint $REST_API_ENDPOINT_HEALTH is not supported anymore on the queried version: ${KLM_VERSION}, endpoint only available in SKLM 4.0"
      return $func_rc
   fi

   if (( $func_rc == 0 )) ; then

       cmd_msg=`${CURL_TOOL} --max-time 40 -sS -k -X GET -H 'Accept:application/json' -H 'Content-type:application/json' https://${REST_API_ADDRESS}${REST_API_ENDPOINT_HEALTH} 2> /dev/null`
       cmd_rc=$?

       if (( $cmd_rc !=0 )); then
          print_line 2 "API endpoint query to https://${REST_API_ADDRESS}/${REST_API_ENDPOINT_HEALTH} failed - with curl"
          func_rc=2
          return 2
       fi
       cmd_msg=`printf $cmd_msg | $PYTHON_TOOL -m json.tool 2> /dev/null | grep overall 2> /dev/null`
       cmd_rc=$?

       if (( $cmd_rc !=0 )); then 
          func_rc=1 
          print_line 2 "JSON decoding failed"
          return $func_rc
       fi
 
   fi

   if (( $func_rc == 0 )); then 
     if [[ $cmd_msg == *true* ]]; then
         print_line 0 "API endpoint $REST_API_ENDPOINT_HEALTH reported good state: $cmd_msg"  
     else
         print_line 2 "API endpoint $REST_API_ENDPOINT_HEALTH reported BAD state: $cmd_msg"
         func_rc=2
         return $func_rc
     fi
   fi

   return $func_rc

}


################################################################################
## Check Args
##
## Ensure valid paramters are given
################################################################################
if (( $# == 0 ));
then
   opt="-a"
else
   opt="$1"
fi



case "$opt" in
   "-a")  echo
		  echo
		  printf "%-29s %s\n" "utility name: " $0
		  printf "%-29s %s\n" "utility version:"  $TOOL_VERSION
		  printf "%-29s %s\n" "checking agains KLM version:" $KLM_VERSION
		  printf "%-29s %s\n" "using config file:" $DEF_FILE_NAME
		  echo
		  
	      # check REST API status
		  check_api_status
          func_rc=$?
          if (( $func_rc > $exit_rc )); then exit_rc=$func_rc; fi
		  
		  # check filesystem utilisation
		  check_filesystems
		  func_rc=$?
		  if (( $func_rc > $exit_rc )); then exit_rc=$func_rc; fi
		  
		  # check listener ports
		  check_ports
		  func_rc=$?
		  if (( $func_rc > $exit_rc )); then exit_rc=$func_rc; fi		  
		  
		  # check running processes
		  check_processes
		  func_rc=$?
		  if (( $func_rc > $exit_rc )); then exit_rc=$func_rc; fi

		  # check if backup is needed
		  check_isBackupNeeded
		  func_rc=$?
		  if (( $func_rc > $exit_rc )); then exit_rc=$func_rc; fi
		  
		  print_line $exit_rc highest returncode
		  ;;
		  
   "-r")  # check REST API status
		  check_api_status
          func_rc=$?
          if (( $func_rc > $exit_rc )); then exit_rc=$func_rc; fi
		  ;;
		  
   "-f")  # check filesystem utilisation
		  check_filesystems
		  func_rc=$?
		  if (( $func_rc > $exit_rc )); then exit_rc=$func_rc; fi
		  ;;
   
   "-l")  # check listener ports
		  check_ports
		  func_rc=$?
		  if (( $func_rc > $exit_rc )); then exit_rc=$func_rc; fi
		  ;;

   "-p")  # check running processes
		  check_processes
		  func_rc=$?
		  if (( $func_rc > $exit_rc )); then exit_rc=$func_rc; fi
		  ;;
		

   "-b")  # check if backup is needed
		  check_isBackupNeeded
		  func_rc=$?
		  if (( $func_rc > $exit_rc )); then exit_rc=$func_rc; fi
		  ;;		
   "-h")  error_usage
		  exit_rc=2
		  ;;
		  
   *)  	  error_usage
		  print_line 2 "wrong command line parameters" 
		  exit_rc=2
	      ;;
esac


exit $exit_rc
