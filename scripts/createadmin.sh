#!/bin/bash

set -e


#Creates weblogic deployment model for cluster domain admin setup
function create_admin_model()
{
    echo "Creating admin domain model"
    cat <<EOF >$DOMAIN_PATH/admin-domain.yaml
domainInfo:
   AdminUserName: "$wlsUserName"
   AdminPassword: "$wlsPassword"
   ServerStartMode: prod
topology:
   Name: "$wlsDomainName"
   AdminServerName: admin
   Machine:
     '$nmHost':
         NodeManager:
             ListenAddress: "$nmHost"
             ListenPort: $nmPort
             NMType : ssl
   Cluster:
        '$wlsClusterName':
             MigrationBasis: 'consensus'
   Server:
        '$wlsServerName':             
            ListenPort: $wlsAdminPort
            RestartDelaySeconds: 10
            SSL:
               ListenPort: $wlsSSLAdminPort
               Enabled: true
   SecurityConfiguration:
       NodeManagerUsername: "$wlsUserName"
       NodeManagerPasswordEncrypted: "$wlsPassword"
EOF
}

function create_adminSetup()
{
	create_admin_model
	chown -R $username:$groupname $DOMAIN_PATH
	runuser -l oracle -c ". $oracleHome/oracle_common/common/bin/setWlstEnv.sh; $DOMAIN_PATH/weblogic-deploy/bin/createDomain.sh -oracle_home $oracleHome -domain_parent $DOMAIN_PATH  -domain_type WLS -model_file $DOMAIN_PATH/admin-domain.yaml"

	echo "Created admin domain ......."
        #runuser -l oracle -c "sudo cp ${DOMAIN_PATH}/${wlsDomainName}/security/SerializedSystemIni.dat ${SHARED_DIR}/"
        sudo cp ${DOMAIN_PATH}/${wlsDomainName}/security/SerializedSystemIni.dat ${SHARED_DIR} 

}

#Function to setup admin boot properties
function admin_boot_setup()
{
 mkdir -p "$DOMAIN_PATH/$wlsDomainName/servers/admin/security"
 echo "username=$wlsUserName" > "$DOMAIN_PATH/$wlsDomainName/servers/admin/security/boot.properties"
 echo "password=$wlsPassword" >> "$DOMAIN_PATH/$wlsDomainName/servers/admin/security/boot.properties"
 chown -R $username:$groupname $DOMAIN_PATH/$wlsDomainName/servers
}

# Create systemctl service for nodemanager
function create_nodemanager_service()
{
 sed -i.bak -e 's/CrashRecoveryEnabled=false/CrashRecoveryEnabled=true/g'  $DOMAIN_PATH/$wlsDomainName/nodemanager/nodemanager.properties
 if [ $? != 0 ];
 then
   echo "Warning : Failed in setting option CrashRecoveryEnabled=true. Continuing without the option."
   mv $DOMAIN_PATH/nodemanager/nodemanager.properties.bak $DOMAIN_PATH/$wlsDomainName/nodemanager/nodemanager.properties
 fi
 sudo chown -R $username:$groupname $DOMAIN_PATH/$wlsDomainName/nodemanager/nodemanager.properties*
 echo "Creating NodeManager service"
 cat <<EOF >/etc/systemd/system/wls_nodemanager.service
 [Unit]
Description=WebLogic nodemanager service

[Service]
Type=simple
# Note that the following three parameters should be changed to the correct paths
# on your own system
WorkingDirectory="$DOMAIN_PATH/$wlsDomainName"
ExecStart="$DOMAIN_PATH/$wlsDomainName/bin/startNodeManager.sh"
ExecStop="$DOMAIN_PATH/$wlsDomainName/bin/stopNodeManager.sh"
User=oracle
Group=oracle
KillMode=process
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
}

# This function to create adminserver service
function create_adminserver_service()
{
 echo "Creating admin server service"
 cat <<EOF >/etc/systemd/system/wls_admin.service
[Unit]
Description=WebLogic Adminserver service

[Service]
Type=simple
WorkingDirectory="$DOMAIN_PATH/$wlsDomainName"
ExecStart="$DOMAIN_PATH/$wlsDomainName/startWebLogic.sh"
ExecStop="$DOMAIN_PATH/$wlsDomainName/bin/stopWebLogic.sh"
User=oracle
Group=oracle
KillMode=process
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
}

function enabledAndStartNodeManagerService()
{
  systemctl enable wls_nodemanager
  systemctl daemon-reload

  attempt=1
  while [[ $attempt -lt 6 ]]
  do
     echo "Starting nodemanager service attempt $attempt"
     systemctl start wls_nodemanager
     sleep 1m
     attempt=`expr $attempt + 1`
     systemctl status wls_nodemanager | grep running
     if [[ $? == 0 ]];
     then
         echo "wls_nodemanager service started successfully"
	 break
     fi
     sleep 3m
 done
}

function enableAndStartAdminServerService()
{
  systemctl enable wls_admin
  systemctl daemon-reload
  echo "Starting admin server service"
  systemctl start wls_admin

}

#This function to wait for admin server
function wait_for_admin()
{
 #wait for admin to start
count=1
export CHECK_URL="http://$wlsAdminURL/weblogic/ready"
echo "Ready App url ::::::: $CHECK_URL "
status=`curl --insecure -ILs $CHECK_URL | tac | grep -m1 HTTP/1.1 | awk {'print $2'}`
echo "Waiting for admin server to start"
while [[ "$status" != "200" ]]
do
  echo $status
  echo "."
   
  count=$((count+1))
  if [ $count -le 30 ];
  then
      sleep 1m
  else
     echo "Error : Maximum attempts exceeded while starting admin server"
     exit 1
  fi
  status=`curl --insecure -ILs $CHECK_URL | tac | grep -m1 HTTP/1.1 | awk {'print $2'}`
  if [ "$status" == "200" ];
  then
     echo "Server $wlsServerName started succesfully..."
     break
  fi
done
}



DOMAIN_PATH="/u01/domains"
BASE_DIR="/vagrant/installers"
SHARED_DIR="/vagrant/shared"
SCRIPTS="/u01/app/scripts"
username="oracle"
groupname="oracle"
wlsDomainName=$DOMAINNAME
wlsUserName=$WLUSER
wlsPassword=$WLPASS
wlsServerName="admin"
wlsAdminHost=$ADMINHOST
oracleHome="/u01/app/wls/install/oracle/middleware/oracle_home"
wlsAdminPort=$ADMINSERVERPORT
wlsSSLAdminPort=7002
wlsAdminURL="$wlsAdminHost:$wlsAdminPort"
wlsClusterName=$CLUSTERNAME
nmHost=`hostname`
nmPort=$NMPORT

if [ ! -f $SCRIPTS/VAGRANT_PROVISIONER_MARKER ]
then 
  echo "Setting up admin node ......................."
  create_adminSetup
  create_nodemanager_service
  admin_boot_setup
  create_adminserver_service
  enabledAndStartNodeManagerService
  enableAndStartAdminServerService
  wait_for_admin
  touch $SCRIPTS/VAGRANT_PROVISIONER_MARKER
fi

