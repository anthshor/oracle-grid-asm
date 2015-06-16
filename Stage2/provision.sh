#!/bin/bash

# Proxy
[ -f /vagrant/proxy.env ] && source /vagrant/proxy.env

installPackages()
{
  echo "installing oracle-rdbms-server-12cR1-preinstall" 
  #PACKAGES="oracle-rdbms-server-12cR1-preinstall.x86_64 xorg-x11-xauth.x86_64 xorg-x11-server-utils.x86_64 oracleasm-support.x86_64" 
}

createGroups()
{
  # grid and oracle user
  #create the extra groups for db12c role separation
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
  mkdir -p /u01 /u02 /u03
  mkdir -p /u01/stage

  pushd /u01/stage
    unzip -n /u01/software/linuxamd64_12102_database_1of2.zip
    unzip -n /u01/software/linuxamd64_12102_database_2of2.zip
    unzip -n /u01/software/linuxamd64_12102_grid_1of2.zip
    unzip -n /u01/software/linuxamd64_12102_grid_2of2.zip
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
