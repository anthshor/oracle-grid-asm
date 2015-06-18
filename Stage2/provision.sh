#!/bin/bash

# Provisioning script for Oracle Grid and ASM
# -------------------------------------------

# define the global variables

export STAGE="/u01/stage"
export SOFTWARE="/u01/software"

###################
#
# Functions
#
###################

installPackages()
{
  echo "installing oracle pre-requirements" 
  PACKAGES="oracle-rdbms-server-12cR1-preinstall.x86_64 xorg-x11-xauth.x86_64 xorg-x11-server-utils.x86_64 oracleasm-support.x86_64" 
  rpm -q $PACKAGES 
  if [ $? -ne 0 ]; then 
    #yum clean all 
    yum -y install $PACKAGES  
  fi
}

createGroups()
{
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

createUsers()
{
  #create or modify as required user grid and oracle
  echo "verifying grid user"
  id grid   2>&1  > /dev/null  && usermod -a -g oinstall -G asmdba,asmadmin,asmoper,dba grid || useradd -u 54320 -g oinstall -G asmdba,asmadmin,asmoper,dba grid
  echo "verifying oracle user"
  id oracle 2>&1 > /dev/null  && usermod -a -g oinstall -G dba,asmdba,backupdba,oper,dgdba,kmdba oracle   || useradd -u 54321 -g oinstall -G dba,asmdba,backupdba,oper,dgdba,kmdba oracle

  #set initial password
  echo oracle | passwd --stdin oracle
  echo grid   | passwd --stdin grid
}


unpackSoftware()
{
  # Unpack previously downloaded software
  [ -d /u01 ] || mkdir /u01 
  [ -d /u02 ] || mkdir /u02 
  [ -d /u03 ] || mkdir /u03
  [ -d ${STAGE} ] || mkdir ${STAGE}

  pushd ${STAGE}
    unzip -n ${SOFTWARE}/linuxamd64_12102_database_1of2.zip 
    unzip -n ${SOFTWARE}/linuxamd64_12102_database_2of2.zip
    unzip -n ${SOFTWARE}/linuxamd64_12102_grid_1of2.zip
    unzip -n ${SOFTWARE}/linuxamd64_12102_grid_2of2.zip
  popd
}

createDirectories()
{
  mkdir -p /u01/12.1.0/grid
  mkdir -p /u01/app/12.1.0/grid
  mkdir -p /u01/app/grid
  mkdir -p /u01/app/oracle
  
  # Update permissions
  chown -R grid:oinstall /u01
  chmod -R 775 /u01/
  chown oracle:oinstall /u01/app/oracle

}

addUmask()
{
  grep "umask 022" /home/grid/.bash_profile 
  if [ $? -ne 0 ]; then
    su - grid -c 'echo "umask 022" >> .bash_profile;'
  fi
}

addResourceLimits()
{
  # Review runInstaller with no settings to determine which are needed
  # Starting with a clean box - assume parameters are not larger
  # PENDING 20150618: Add in check for 'unlimited'

  if [ `ulimit -Sn` -lt  "1024" ]; then echo "grid     soft     nofile       1024" >> /etc/security/limits.conf; fi
  if [ `ulimit -Hn` -lt "65536" ]; then echo "grid     hard     nofile      65536" >> /etc/security/limits.conf; fi
  if [ `ulimit -Su` -lt  "2047" ]; then echo "grid     soft     nproc        2047" >> /etc/security/limits.conf; fi
  if [ `ulimit -Hu` -lt "16384" ]; then echo "grid     hard     nproc       16384" >> /etc/security/limits.conf; fi
  if [ `ulimit -Ss` -lt "10240" ]; then echo "grid     soft     stack       10240" >> /etc/security/limits.conf; fi
  if [ `ulimit -Hs` -lt "32768" ]; then echo "grid     hard     stack       32768" >> /etc/security/limits.conf; fi
}
 
configureOracleASM()
{
  /usr/sbin/oracleasm configure -i

}
   
   
   
   
   



##############
#
# Main
#
#############

# Proxy
[ -f /vagrant/proxy.env ] && source /vagrant/proxy.env

installPackages
createGroups
createUsers
unpackSoftware
createDirectories
addUmask
addResourceLimits