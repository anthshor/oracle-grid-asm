#!/bin/bash

# Provisioning script for Oracle Grid and ASM
# -------------------------------------------
# define the global variables
export STAGE="/u01/stage"
export SOFTWARE="/u01/software"
export PASSWORD="Password1#"
export GRID_HOME="/u01/12.1.0/grid"

###################
# Functions
###################

installPackages(){
  PACKAGES=$@
  rpm -q $PACKAGES 
  if [ $? -ne 0 ]; then 
    yum -y install $PACKAGES  
  fi
}

removePackages(){
  PACKAGES=$@
  rpm -q $PACKAGES 
  if [ $? -eq 0 ]; then 
    yum -y remove $PACKAGES  
  fi
}

createGroups(){
  # create the extra groups for db12c role separation
  echo "Checking groups for grid and oracle user"

  grep ^asmdba:    /etc/group 2>&1 > /dev/null || groupadd -g 54318 asmdba
  grep ^asmoper:   /etc/group 2>&1 > /dev/null || groupadd -g 54319 asmoper
  grep ^asmadmin:  /etc/group 2>&1 > /dev/null || groupadd -g 54320 asmadmin
  grep ^oinstall:  /etc/group 2>&1 > /dev/null || groupadd -g 54321 oinstall
  grep ^dba:       /etc/group 2>&1 > /dev/null || groupadd -g 54322 dba
  grep ^backupdba: /etc/group 2>&1 > /dev/null || groupadd -g 54323 backupdba
  grep ^oper:      /etc/group 2>&1 > /dev/null || groupadd -g 54324 oper
  grep ^dgdba:     /etc/group 2>&1 > /dev/null || groupadd -g 54325 dgdba
  grep ^kmdba:     /etc/group 2>&1 > /dev/null || groupadd -g 54326 kmdba
}

createUsers(){
  #create or modify as required user grid and oracle
  echo "verifying grid user"
  id grid   2>&1  > /dev/null  && usermod -a -g oinstall -G asmdba,asmadmin,asmoper,dba grid || useradd -u 54320 -g oinstall -G asmdba,asmadmin,asmoper,dba grid
  echo "verifying oracle user"
  id oracle 2>&1 > /dev/null  && usermod -a -g oinstall -G dba,asmdba,backupdba,oper,dgdba,kmdba oracle   || useradd -u 54321 -g oinstall -G dba,asmdba,backupdba,oper,dgdba,kmdba oracle

  #set initial password
  echo oracle | passwd --stdin oracle
  echo grid   | passwd --stdin grid
}


unpackSoftware(){
  # Unpack previously downloaded software
  [ -d /u01 ] || mkdir /u01 
  [ -d /u02 ] || mkdir /u02 
  [ -d /u03 ] || mkdir /u03
  [ -d ${STAGE} ] || mkdir ${STAGE}

  pushd ${STAGE}
    [ -f ${SOFTWARE}/linuxamd64_12102_database_1of2.zip ] && unzip -n ${SOFTWARE}/linuxamd64_12102_database_1of2.zip
    unzip -n ${SOFTWARE}/linuxamd64_12102_database_2of2.zip
    unzip -n ${SOFTWARE}/linuxamd64_12102_grid_1of2.zip
    unzip -n ${SOFTWARE}/linuxamd64_12102_grid_2of2.zip
  popd
}

createDirectories(){
  mkdir -p /u01/12.1.0/grid
  mkdir -p /u01/app/12.1.0/grid
  mkdir -p /u01/app/grid
  mkdir -p /u01/app/oracle
  
  # Update permissions
  chown -R grid:oinstall /u01
  chmod -R 775 /u01/
  chown oracle:oinstall /u01/app/oracle
}

addUmask(){
  #WHY???
  grep "umask 022" /home/grid/.bash_profile 
  if [ $? -ne 0 ]; then
    su - grid -c 'echo "umask 022" >> .bash_profile;'
  fi
}

addResourceLimits(){
  # Review runInstaller with no settings to determine which are needed
  # Starting with a clean box - assume parameters are not larger

  updateLimits(){
    if [ $# -eq 4 ]; then
      [ -f /etc/security/limits.conf.ori ] || cp /etc/security/limits.conf /etc/security/limits.conf.ori
      > /etc/security/limits.conf.tmp
      mv /etc/security/limits.conf /etc/security/limits.conf.tmp
      grep -v -E "$2.*.$3" /etc/security/limits.conf.tmp >> /etc/security/limits.conf
      echo $@ >> /etc/security/limits.conf
    fi
  }

  if [ `ulimit -Sn` -lt  1024 ]; then updateLimits grid     soft     nofile       1024 ; fi
  if [ `ulimit -Hn` -lt 65536 ]; then updateLimits grid     hard     nofile      65536 ; fi
  if [ `ulimit -Su` -lt  2047 ]; then updateLimits grid     soft     nproc        2047 ; fi
  if [ `ulimit -Hu` -lt 16384 ]; then updateLimits grid     hard     nproc       16384 ; fi
  if [ `ulimit -Ss` -lt 10240 ]; then updateLimits grid     soft     stack       10240 ; fi
  if [ `ulimit -Hs` = "unlimited" ] || [ `ulimit -Hs` -lt 32768 ]; then updateLimits grid     hard     stack       32768 ; fi
}
 
createPT()
{
  #ugly
  # Create partition table and write it to disk
  if [ ! -e /dev/${1}1 ]; then
    for disk in $1 ; do
    fdisk /dev/$disk  << EOF
n
p
1
1

w
EOF
    done
    if [ $? -ne 0 ]; then
      echo "Something went wrong with fdisk"
      exit
    fi
  fi
}

serviceNTP()
{
  if [ $1 = "on" ]; then
    service ntpd status && service ntpd restart || service ntpd start
    chkconfig ntpd on
  elif [ $1 = "off" ]; then
    service ntpd stop
    chkconfig ntpd off
  fi
}

installGrid()
{
  #sudo -E -H -u grid command variables \
  #more variables

  #data
  chown grid:asmadmin /dev/sdb
  #fra
  chown grid:asmadmin /dev/sdc

  sudo -E -H -u grid /u01/stage/grid/runInstaller -silent -waitforcompletion \
oracle.install.asm.SYSASMPassword=${PASSWORD} oracle.install.asm.monitorPassword=${PASSWORD} \
ORACLE_HOSTNAME=${HOSTNAME} \
INVENTORY_LOCATION=/u01/app/oraInventory \
SELECTED_LANGUAGES=en \
oracle.install.option=HA_CONFIG \
ORACLE_BASE=/u01/app/grid \
ORACLE_HOME=/u01/12.1.0/grid \
oracle.install.asm.OSDBA=asmdba \
oracle.install.asm.OSOPER=asmoper \
oracle.install.asm.OSASM=asmadmin \
oracle.install.crs.config.ClusterType=STANDARD \
oracle.install.crs.config.gpnp.configureGNS=false \
oracle.install.crs.config.autoConfigureClusterNodeVIP=true \
oracle.install.crs.config.gpnp.gnsOption=CREATE_NEW_GNS \
oracle.install.crs.config.sharedFileSystemStorage.votingDiskRedundancy=NORMAL \
oracle.install.crs.config.sharedFileSystemStorage.ocrRedundancy=NORMAL \
oracle.install.crs.config.useIPMI=false \
oracle.install.asm.diskGroup.name=DATA \
oracle.install.asm.diskGroup.redundancy=EXTERNAL \
oracle.install.asm.diskGroup.AUSize=1 \
oracle.install.asm.diskGroup.disks=/dev/sdb \
oracle.install.asm.diskGroup.diskDiscoveryString=/dev/sd* \
oracle.install.crs.config.ignoreDownNodes=false \
oracle.install.config.managementOption=NONE \
oracle.install.config.omsPort=0

/u01/app/oraInventory/orainstRoot.sh
/u01/12.1.0/grid/root.sh

export RESPONSE_FILE=/var/tmp/cf.rsp

> ${RESPONSE_FILE}
echo "oracle.assistants.asm|S_ASMPASSWORD=${PASSWORD}" >> ${RESPONSE_FILE}
echo "oracle.assistants.asm|S_ASMMONITORPASSWORD=${PASSWORD}" >> ${RESPONSE_FILE}
chmod 600 ${RESPONSE_FILE}
chown grid:oinstall ${RESPONSE_FILE}

sudo -E -H -u grid /u01/12.1.0/grid/cfgtoollogs/configToolAllCommands RESPONSE_FILE=${RESPONSE_FILE}

}

runASMCA()
{
  sudo -E -H -u grid ${GRID_HOME}/bin/asmca -silent -createDiskGroup -diskGroupName $1 -disk /dev/sdc \
-redundancy EXTERNAL -sysAsmPassword ${PASSWORD}
}
#  /etc/resolv.conf - can't find logitech: NXDOMAIN
   
   
##############
#
# Main
#
#############

# Proxy
[ -f /vagrant/proxy.env ] && source /vagrant/proxy.env

installPackages oracle-rdbms-server-12cR1-preinstall.x86_64 xorg-x11-xauth.x86_64 xorg-x11-server-utils.x86_64 ntp
# Install following for graphical install
installPackages tigervnc-server xterm twm 
serviceNTP on
createGroups
createUsers
unpackSoftware
createDirectories
addUmask
addResourceLimits
# Install grid and asm
[ -f ${GRID_HOME}/root.sh ] || installGrid
# Add FRA disk group
[ `su grid -c "/u01/12.1.0/grid/bin/asmcmd ls | grep -i fra | wc -l"` -ne 0 ] || runASMCA FRA

# Add manual ASMFD steps to script 20150620
# Remember to run this post root scripts if cluster...
# /u01/12.1.0/grid_1/perl/bin/perl -I/u01/12.1.0/grid_1/perl/lib -I/u01/12.1.0/grid_1/crs/install /u01/12.1.0/grid_1/crs/install/roothas.pl
# ASMFD requires asm to be installed to configure??

true