#!/bin/bash
################################################################################
# Name:     IBM Security Guardium Key Lifecycle Manager port checker           #
#                                                                              #
# Author:   Daniel Wendler                                                     #
#                                                                              #
TOOL_VERSION="0.10"                                                            #
#                                                                              #
# Dependencies:                                                                #
#   - lsof, nc (netcat)                                                        #
#                                                                              #
# Github Repository:                                                           #
# https://github.com/IBM/klmutils                                              #
################################################################################


isMultiMaster=true
klmVersion="411"    # can be: "31", "40", "41", "411"

LSOF_TOOL="/usr/bin/lsof"
NC_TOOL="/usr/bin/nc"

toolsList=($LSOF_TOOL $NC_TOOL)
rc=0

portsCommon=(1441 3801 5696 9443)
portsMC=(1111 2222)
portsMM31=(60015 50050 60025)       #apply to KLM 3.1.0.x
portsMM40=(60015 5006666660 60027)  #apply to KLM 4.0.0.x
portsMM41=(60015 50070 60028)       #apply to KLM 4.1.0.x
portsMM411=(60015 50080 60029)      #apply to KLM 4.1.1.x

case "$klmVersion" in
		"31") 	portsMM=${portsMM31[@]};;
		"40") 	portsMM=${portsMM40[@]};;
		"41") 	portsMM=${portsMM41[@]};;
		"411") 	portsMM=${portsMM411[@]};;
		*)		printf "\n\nERROR: wrong KLM version.\n\n"; exit 123;;
esac



portsCombined=${portsCommon[@]}

if [ $isMultiMaster = true ]; then
        portsCombined+=(${portsMM[@]})
else
        portsCombined+=(${portsMC[@]})
fi


function server
{
   echo
   echo "bringing up tcp listener ports (if not already up): ${portsCombined[@]}"
   echo
   sync

   lsofPorts=""

   for port in ${portsCombined[@]}
   do
      lsofPorts=${lsofPorts:+${lsofPorts},}$port
      command="$NC_TOOL -l -k -4 $port &"
      eval $command
      sync
   done
   sleep 1

   printf "\n\n"
   command="${LSOF_TOOL} -sTCP:LISTEN -Pn -i:$lsofPorts"
   echo $command
   echo
   eval $command

   printf "\n\n"

   read -p "Press enter to stop started listeners and end program"
   echo
   killall $NC_TOOL >/dev/null 2>/dev/null
   echo
   sleep 1
   echo
   sync

   eval $command
   echo
}

function client
{
   printf "\nstarting client connection to server: $remoteHost\n"

   for port in ${portsCombined[@]}
   do
      command="$NC_TOOL -z $remoteHost $port"
      eval $command
      rc=$?
      if (( $rc == 0 )); then msg="success";
      else
         msg="failure"
      fi
      printf "\nconnection to %s:%-5s status: %s" ${remoteHost} ${port} $msg
      sync
   done
   printf "\n\n"
}

clear
for tool in ${toolsList[@]}
do
   if [ ! -f $tool ]; then
        echo "ps utility not found under: $tool"
        rc=2
   fi
done
if (( $rc > 1 )); then echo "tools missing, exiting script "; exit 2; fi


# minimal parameter parsing
if (( $# == 0 ));
then
   type="server"
else
   type="$1"
fi

printf "\nprofile: $klmVersion, MultiMaster: $isMultiMaster, scriptVersion: $TOOL_VERSION\n\n"

case "$type" in
		"server")    server;;
		"client")    if [[ -z $2 ]]; then remoteHost="localhost";
                else remoteHost=$2
                fi
                client;;

		*)           printf "\n\n ERROR: param must be either server or client\n\n";;
esac

echo
