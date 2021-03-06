#!/bin/bash

# define the global variables
export STAGE="/u01/stage"
export SOFTWARE="/u01/software"
export PASSWORD="Password1#"
export VERSION="12.1.0.2"

# Proxy
[ -f /proxy/.proxy.env ] && source /proxy/.proxy.env

# Start NTP daemon
service ntpd status && service ntpd restart || service ntpd start
chkconfig ntpd on

# Installing Grid Infrastructure Using a Software-Only Installation
# NB /etc/resolv.conf - server can't find logitech: NXDOMAIN (skipped prereqs) - fix later
if [ ! -f /u01/app/${VERSION}/grid/root.sh ]; then
  echo "Installing Grid software..."
  sudo -E -H -u grid /u01/stage/grid/runInstaller -silent -ignoreSysPrereqs  -ignorePrereq -waitforcompletion  \
  oracle.install.asm.SYSASMPassword=oracle12 oracle.install.asm.monitorPassword=oracle12 \
  ORACLE_HOSTNAME=logitech.sprite.zero \
  INVENTORY_LOCATION=/u01/app/oraInventory \
  SELECTED_LANGUAGES=en \
  oracle.install.option=CRS_SWONLY \
  ORACLE_BASE=/u01/app/grid \
  ORACLE_HOME=/u01/app/12.1.0.2/grid \
  oracle.install.asm.OSDBA=asmdba \
  oracle.install.asm.OSOPER=asmoper \
  oracle.install.asm.OSASM=asmadmin \
  oracle.install.crs.config.ClusterType=STANDARD \
  oracle.install.crs.config.gpnp.configureGNS=false \
  oracle.install.crs.config.sharedFileSystemStorage.votingDiskRedundancy=NORMAL \
  oracle.install.crs.config.sharedFileSystemStorage.ocrRedundancy=NORMAL \
  oracle.install.crs.config.useIPMI=false \
  oracle.install.crs.config.ignoreDownNodes=false \
  oracle.install.config.managementOption=NONE 


  /u01/app/oraInventory/orainstRoot.sh
  /u01/app/${VERSION}/grid/root.sh

else
  echo "Skipping Grid Installation."
fi

