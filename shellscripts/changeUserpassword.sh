#!/bin/bash

##################################################################################
# The MIT License (MIT)                                                          #
#                                                                                #
# Copyright (c) 2022 Daniel Wendler                                              #
#                                                                                #
# Permission is hereby granted, free of charge, to any person obtaining a copy   #
# of this software and associated documentation files (the "Software"), to deal  #
# in the Software without restriction, including without limitation the rights   #
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell      #
# copies of the Software, and to permit persons to whom the Software is          #
# furnished to do so, subject to the following conditions:                       #
#                                                                                #
# The above copyright notice and this permission notice shall be included in     #
# all copies or substantial portions of the Software.                            #
#                                                                                #
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR     #
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,       #
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE    #
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER         #
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,  #
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE  #
# SOFTWARE.                                                                      #
##################################################################################


##################################################################################
# Name:     IBM Security Guardium Key Lifecycle Manager password change tool     #
# Author:   Daniel Wendler                                                       #
#                                                                                #
TOOL_VERSION="0.10"                                                              #
#                                                                                #
# Dependencies:                                                                  #
#   - Python, curl                                                               #
#                                                                                #
# Github Repository:                                                             #
# https://github.com/dwendler/klmutils moved to                                  #
#                                                                                #
# https://github.com/IBM/klmutils                                                #
#                                                                                # 
##################################################################################


##################################################################################
# Purpose of this script: 													                           	 #
# The script can be used to change the password of a given user via commandline  #
# The indended usecase is to reset the userpassword after every keyretrieve from # 
# a key management system like CyberArk.  										                   #
#																				                                         #
# Password complexity rules for GKLM Application Users:                          #
# Product documentation: 														                             #
# https://www.ibm.com/docs/en/sgklm/4.1.1?topic=manager-changing-password-policy #
# configFile: TKLMPasswordPolicy.xml defines the following default values        #
# Minimum length: 8 chars														                             #
# Maximum length: 20 chars														                           #
# Minimum numbers: 2															                               #
# Minimum alphabetic chars: 3													                           #
# Minimum Upper-case chars: 1													                           # 
# Minimum Lower-case characters: 1 												                       #
# Allowed special chars: ~@_/+:													                         #
# Disallowed special chars: `!#$%^&*()=}{][|"';?.<,>-					              		 #
##################################################################################


# ================================================================================
# BEGIN OF variable declaration ==================================================

# define path of external tools and default values
CURL_TOOL="/usr/bin/curl"
PYTHON_TOOL="/usr/bin/python3"
HOSTNAME="localhost"
PORTNR="9443"
USERNAME="SKLMAdmin"
ResponseFile="response.txt"

# default return code
exit_rc=0

# END definitions ================================================================
# ================================================================================


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

function helpText
{
HELP=`cat <<EOF
  
   IBM Security Guardium Key Lifecycle Manager password change tool, version $TOOL_VERSION (MIT licence)
   
   usage: $0 [ -h hostname -p klmPortNumber -o oldPassword -n newPassword

   syntax:
     -h  --> IP or FQDN of the keyserver (optional, defauls: localhost)
     -p  --> TCP port of the KLM REST API (optional, default: 9443)
     -o  --> Current password (required)
     -n  --> New password (required)
     -u  --> username (optional, default: SKLMAdmin)
     -?  --> Print This Help Screen
	 

EOF`
  printf "$HELP"
  echo
  exit 2
}


function checkTools
{
	func_rc=0
	if [ ! -f $CURL_TOOL ]; then 
      func_rc=2
      print_line 2 "curl tool not found under: $CURL_TOOL"
	fi

	if [ ! -f $PYTHON_TOOL ]; then 
      func_rc=2
      print_line 2 "python tool not found under: $PYTHON_TOOL"
	fi
	return $func_rc
}


function getSessionToken
{	
	#https://stackoverflow.com/questions/38906626/curl-to-return-http-status-code-along-with-the-response
	
	endpoint="https://${HOSTNAME}:${PORTNR}/SKLM/rest/v1/ckms/login"
	headers=" -H 'Accept:application/json' -H 'Content-type:application/json' "
	body='{"userid" : "'$USERNAME'", "password" : "'$PASSOLD'" }'
    #http_response=`curl -s -k -o $ResponseFile -w "%{http_code}" -X POST $headers -d $body $endpoint`
	#http_response=`curl -s -k -o $ResponseFile -w "%{http_code}" -X POST -H 'Accept:application/json' -H 'Content-type:application/json' -d '{"userid" : "'$USERNAME'", "password" : "'$PASSOLD'" }' https://${HOSTNAME}:${PORTNR}/SKLM/rest/v1/ckms/login`
	http_response=`curl -s -k -o $ResponseFile -w "%{http_code}" -X POST -H 'Accept:application/json' -H 'Content-type:application/json' -d '{"userid" : "'$USERNAME'", "password" : "'$PASSOLD'" }' $endpoint`
	#'{"userid" : "'$USERNAME'", "password" : "'$PASSOLD'" }' $endpoint`
	if [ $http_response != "200" ]; then
		# handle error
		print_line 2 "session token can not be captured, http_responseCode: $http_response, exiting ..."
		echo
		cat $ResponseFile
		echo
		echo 
		rm $ResponseFile
		exit 2
	else
		UserAuthId=`cat $ResponseFile | $PYTHON_TOOL -c 'import sys,json; obj=json.load(sys.stdin);print(obj["UserAuthId"])'`
		print_line 0 "Session Token: $UserAuthId"
	fi	 
}

function changePassword
{
	http_response=`curl -s -k -o $ResponseFile -w "%{http_code}" -X PUT -H 'Accept:application/json' -H 'Content-type:application/json' -H "Authorization: SKLMAuth userAuthId=$UserAuthId" -d '{"password" : "'$PASSNEW'" }' https://${HOSTNAME}:${PORTNR}/SKLM/rest/v1/ckms/usermanagement/users/${USERNAME}`
	if [ $http_response != "200" ]; then
		# handle error
		print_line 2 "password could not be updated, http_responseCode: $http_response, exiting ..."
		echo
		cat $ResponseFile
		rm $ResponseFile
		echo
		echo 
		exit 2
	else
		print_line 0 "Password change was successfull"
		#cat $ResponseFile 
		rm $ResponseFile
	fi	 
}



function delSessionToken
{
	http_response=`curl -s -k -o $ResponseFile -w "%{http_code}" -X DELETE -H 'Accept:application/json' -H 'Content-type:application/json' -H "Authorization: SKLMAuth userAuthId=$UserAuthId" -d '{"userAuthId" : "'$UserAuthId'" }' https://${HOSTNAME}:${PORTNR}/SKLM/rest/v1/ckms/logout`
	if [ $http_response != "200" ]; then
		# handle error
		print_line 2 "error destroying session token, http_responseCode: $http_response, exiting ..."
		echo
		cat $ResponseFile
		rm $ResponseFile
		echo
		echo 
		exit 2
	else
		print_line 0 "session token invalidated successfully"
		#cat $ResponseFile 
		rm $ResponseFile
		echo
	fi	 
}

####### check for required tools ##############################################
checkTools
func_rc=$?
if (( $func_rc > $exit_rc )); then 
	exit_rc=$func_rc; 
	exit $exit_rc
fi


################################################################################
## Check Args - Ensure valid paramters are given
################################################################################

while [ $# -gt 0 ] 
do 
	case "$1" in
		"-h" | "-host")  # check if hostname is set
			  shift
			  HOSTNAME=$1
			  ;;        
		"-p")  # check if portnumber 
			  shift
			  PORTNR=$1
			  ;;        
			  
		"-?") helpText
			  exit_rc=2
			  ;;
		
		"-u")  # check and assign username
			  shift
			  USERNAME=$1
			  ;;     

		"-o")  # read current password
			  shift
			  PASSOLD=$1
			  ;;        			  
		"-n")  # assign the new password
			  shift
			  PASSNEW=$1
			  ;;     
		
		*)    helpText
			  print_line 2 "wrong command line parameters" 
			  exit_rc=2
			  ;;
	esac
	shift
done
####### print connection details, clear passwords####################################
printf "\nHostname  : $HOSTNAME\n" 
printf "PortNumber: $PORTNR\n" 
printf "Username  : $USERNAME\n" 
if [ -z "$PASSOLD" ]
then
   msg="current password not defined, exiting\n\n"
   printf "$msg"
   exit 2
else printf "old Pass  : *********\n"
fi

if [ -z "$PASSNEW" ]
then
   msg="new password not defined, exiting\n\n"
   printf "$msg"
   exit 2
else printf "new Pass  : *********\n"
fi

####### run the REST API calls #####################################################
echo
getSessionToken
changePassword
delSessionToken

exit $exit_rc
