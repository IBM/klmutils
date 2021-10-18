#!/bin/bash
# this script runs some prechecks and installs missing software packages from yum repositories

VERSION="0.7"
# author: Dwendler
# history: 
# added logging 
# 0.4 added OS check for RHEL, added parameter install
# 0.5 adjusted script fro RHEL 8, removed screen, added tmux requirement
# 0.6 added ulimit and kernel sem settings
# 0.7 added firewalld and GKLM kernel parameter checkscript


typeset Current_Date_And_Time="$(date "+%m%d%y")_$(date "+%H%M%S")"
typeset Log_File="RHEL8_klm_precheck_${HOSTNAME}_${Current_Date_And_Time}.log"
typeset firewallRules="/tmp/RHEL_klm_precheck_${HOSTNAME}_${Current_Date_And_Time}.iptable.rules"
TMPDIR=/tmp yum repolist

# note tmux is used vs screen. in RHEL 8 screen was marked depricated
# other packaged removed rfrom check to avoid confusion, seems to be not required (anymore?)
# removed: gtk2.x86_64  libXtst.x86_64 compat-libstdc++-33.x86_64 glibc.x86_64

pckarr=( tcsh iptables-services tmux lsof libstdc++.x86_64 libaio.x86_64 )

{
echo
echo precheck script version: $VERSION
echo

continueSilent=0
installPackages=0

if [[ $# -eq 0 ]]; 
then
   continueSilent=0
   installPackages=0
else
   if [ "$1" = "install" ]; then
      installPackages=1
   else
      continueSilent=1
   fi
fi

echo
echo ===============================================================================
echo checking Operating system 
echo ===============================================================================
echo

hostnamectl

os_name='Red Hat'
os_release_filename="/etc/os-release" 
os_name_cnt=`grep -c "$os_name" $os_release_filename`
os_name_cnt_rc=$?

if (( $os_name_cnt_rc !=0 )) || (( $os_name_cnt < 1 ));
then
  echo
  echo ERROR: could not verify OS: \"$os_name\" in file \"$os_release_filename\"
  echo
  echo "exiting ..."
  exit 1
fi


echo
echo
echo
echo ===============================================================================
echo checking and installing required packages 
echo ===============================================================================
echo
echo install missing packages param \"install\": $installPackages
echo

for i in  ${pckarr[*]}
 do
  isinstalled=$(rpm -q $i)
  if [ !  "$isinstalled" == "package $i is not installed" ];
   then
    echo Package $i already installed
  else
    echo Package $i is NOT installed !!!!
    if [[ $installPackages -eq 1 ]]; then
       yum install $i -y
	echo
	echo
    fi
  fi
done
if [[ $installPackages -eq 1 ]]; then
   echo "exiting after installation"
   exit
fi


echo
echo
sync;
if [[ $continueSilent -eq 0 ]]; then
   read -n1 -r -p "Press space to continue..." key   
fi


echo
echo
echo ==========================================================================
echo checking /etc/ssh/sshd_config
echo ==========================================================================
echo
echo system config:
grep ClientAlive /etc/ssh/sshd_config
echo 
echo recommended settings for silent install:
echo INFO: "ClientAliveInterval 1200	# 20 minutes"
echo INFO: "ClientAliveCountMax 9	# 9 x 20 minutes => 180mins, 3hours"
echo INFO:  restart sshd after the modification with the command: 
echo cmd:   \"systemctl restart sshd.service\"
echo
echo
sync;
if [[ $continueSilent -eq 0 ]]; then
   read -n1 -r -p "Press space to continue..." key   
fi

echo
echo
echo ==========================================================================
echo checking firewalls and rules
echo ==========================================================================
echo
echo 
echo ** checking for iptables and rules

echo
iptables_status=`sudo systemctl status iptables`
rc=$?
if [[ $rc -eq 0 ]]; then 
   echo saving current iptabled rules to file: \"$firewallRules\"
   iptables-save > $firewallRules
   iptables -L -n
else 
   echo iptables not configured / not started
fi




echo
echo checking for firewalld 
firewalld_status=`sudo systemctl status firewalld`
rc=$?
if [[ $rc -eq 0 ]]; then 
   sudo firewall-cmd --get-zones
   sudo firewall-cmd --list-all
   sudo firewall-cmd --list-services
   sudo firewall-cmd --list-ports
else 
   echo firewalld not configured / notstarted
fi


# auto disable of firewall has been removed 
#echo
#echo disabling firewall
#echo
#systemctl stop firewalld
#systemctl mask firewalld
#systemctl disable firewalld
#systemctl status firewalld
#
#systemctl enable iptables.service
#iptables -F
#/usr/libexec/iptables/iptables.init save
#
#echo
#iptables --list

echo
echo
sync;
if [[ $continueSilent -eq 0 ]]; then
   read -n1 -r -p "Press space to continue..." key   
fi

echo
echo
echo ==========================================================================
echo checking SElinux
echo ==========================================================================
echo
echo INFO: /etc/sysconfig/selinux may need to be adjusted to mode SELINUX=disabled or permissive
echo INFO: a reboot is required after changes are made

echo CMD:  sestatus
echo
sestatus
echo
echo
echo CMD:  getenforce
echo
getenforce

echo
echo
sync;
if [[ $continueSilent -eq 0 ]]; then
   read -n1 -r -p "Press space to continue..." key   
fi


echo
echo
echo ==========================================================================
echo checking umask
echo ==========================================================================
echo
echo "grep umask /etc/profile /etc/bashrc"
grep umask /etc/profile /etc/bashrc
echo
echo


echo
echo
echo ==========================================================================
echo checking mount point /tmp and /home for noexec and nosuid flag
echo ==========================================================================
echo
#mount -o remount,exec /tmp
mount | grep -e "/tmp" -e "/home"
echo
echo "in case noexec is set, remount tmp directory:"
echo "command: mount -o remount,exec /tmp"
echo
echo


echo
echo
echo ==========================================================================
echo checking filesystem utilization
echo ==========================================================================
echo
df -h /tmp /root /home /opt /var
echo 
echo
echo 
df -h -P

echo
echo
sync;
if [[ $continueSilent -eq 0 ]]; then
   read -n1 -r -p "Press space to continue..." key   
fi

echo
echo
echo ==========================================================================
echo Kernel settings
echo ==========================================================================
echo

kernelcheck=false
kernelscriptfile="kernelParameters_verbose.sh"

#if [ "$kernelcheck" = true ];
if [ -x $kernelscriptfile  ];
then 
   echo "executing GKLM pre-req checkscript for kernel parameters"
   ./${kernelscriptfile} 
else

   echo "GKLM pre-req checkscript ${kernelscriptfile} not found or not executable"

   echo current settings:
   sysctl -a | grep kernel.sem
   sysctl -a | grep kernel.msgmni
   echo
   echo "required settings for 16GB RAM: in /etc/sysctl.conf"
   echo kernel.msgmni=16384 
   echo kernel.sem=\"250 32000 100 1024\" 
   echo 'check here for details: https://www.ibm.com/docs/en/db2/11.5?topic=unix-modifying-kernel-parameters-linux'

fi

echo
echo
echo ==========================================================================
echo ulimits
echo ==========================================================================
echo
echo current settings:
ulimit -a
echo
echo "required settings: TBD "

echo
echo
echo ==========================================================================
echo OS language
echo ==========================================================================
echo
echo language must be set to english:
echo 
env | grep -e LANG -e LC_
echo
echo

echo
echo
echo ==========================================================================
echo RAM and SWAP
echo ==========================================================================
echo
echo "current settings:"
free
echo
echo

echo
echo
echo ==========================================================================
echo CPU
echo ==========================================================================
echo
echo "current settings:"
lscpu
echo
echo

echo
echo
echo ==========================================================================
echo host name / DNS information
echo ==========================================================================
echo
echo "/etc/hosts"
cat /etc/hosts
echo
hostname=`hostname`
hostnameI=`hostname -i`
echo "hostname   : $hostname"
echo "hostname -i: $hostnameI"
echo
echo nslookup $hostname
nslookup $hostname
echo
echo /etc/resolv.conf
cat /etc/resolv.conf
echo
echo
sync;
if [[ $continueSilent -eq 0 ]]; then
   read -n1 -r -p "Press space to continue..." key   
fi

echo
echo
echo ==========================================================================
echo services etc
echo ==========================================================================
echo
echo grep klm /etc/services
grep -e klmdb /etc/services
echo
echo
echo

echo ==========================================================================
echo users
echo ==========================================================================
echo
echo grep -e klm -e klmfcusr /etc/passwd
grep -e klm -e klmfcusr /etc/passwd
echo
echo getent passwd | grep -e klm -e klmfuser
getent passwd | grep -e klm -e klmfuser
echo
echo

echo
echo
echo ==========================================================================
echo checking if requirements check will be skipped
echo ==========================================================================

echo "it is highly recommended to run the preReq script to ensure all requirements are met:"
echo "disk1/precheckscripts/preReqCheck.sh"
echo

precheck=`grep -c SKIP_PREREQ=true /tmp/sklmInstall.properties` 2> /dev/null
cmd_rc=$?

if (( $cmd_rc !=0 )) || (( $precheck < 1 ));
then
   echo
   echo INFO: could not verify precheck settings or not set
   echo INFO: recommended settings to skip CPU, RAM, OS, filesystem space requirements:
   echo 'CMD:  echo SKIP_PREREQ=true > /tmp/sklmInstall.properties'
else
   echo pre-check will be skipped

fi


} | tee $Log_File


echo
echo
echo "#########################################################################################"
echo
echo "  output of this script is logged to: $Log_File"
echo
echo "#########################################################################################"
