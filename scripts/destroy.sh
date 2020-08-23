#!/bin/bash


DOMAIN_PATH="/u01/domains" 
oracleHome="/u01/app/wls/install/oracle/middleware/oracle_home"
username="oracle"
groupname="oracle"


echo "removing managed server and machine from domain before destroying VM"
runuser -l oracle -c ". $oracleHome/oracle_common/common/bin/setWlstEnv.sh; java  weblogic.WLST $DOMAIN_PATH/removenode.py"

exit 0 
