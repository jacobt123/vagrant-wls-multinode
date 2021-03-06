#!/bin/bash

set -e

# Create managed server setup
function create_managedSetup(){
    echo "Creating Managed Server Setup"
    echo "Downloading weblogic-deploy-tool"

    DOMAIN_PATH="/u01/domains" 
    mkdir -p $DOMAIN_PATH 
    echo "Creating managed server model files"
    create_managed_model
    create_machine_server
    echo "Completed managed server model files"
    chown -R $username:$groupname $DOMAIN_PATH
    runuser -l oracle -c ". $oracleHome/oracle_common/common/bin/setWlstEnv.sh; $DOMAIN_PATH/weblogic-deploy/bin/createDomain.sh -oracle_home $oracleHome -domain_parent $DOMAIN_PATH  -domain_type WLS -model_file $DOMAIN_PATH/managed-domain.yaml"
    if [[ $? != 0 ]]; then
       echo "Error : Managed setup failed"
       exit 1
    fi
    sudo cp ${SHARED_DIR}/SerializedSystemIni.dat ${DOMAIN_PATH}/${wlsDomainName}/security/   
    chown -R $username:$groupname ${DOMAIN_PATH}/${wlsDomainName}/security/
    echo "Adding machine $hostName and managed server $wlsServerName"
    runuser -l oracle -c ". $oracleHome/oracle_common/common/bin/setWlstEnv.sh; java $WLST_ARGS weblogic.WLST $DOMAIN_PATH/add-node.py"
    if [[ $? != 0 ]]; then
         echo "Error : Adding machine and managed server $wlsServerName failed"
         exit 1
    fi
}

#Creates weblogic deployment model for cluster domain managed server
function create_managed_model()
{
    echo "Creating managed domain model"
    cat <<EOF >$DOMAIN_PATH/managed-domain.yaml
domainInfo:
   AdminUserName: "$wlsUserName"
   AdminPassword: "$wlsPassword"
   ServerStartMode: prod
topology:
   Name: "$wlsDomainName"
   Machine:
     '$hostName':
         NodeManager:
             ListenAddress: "$nmHost"
             ListenPort: $nmPort
             NMType : ssl
   Cluster:
        '$wlsClusterName':
             MigrationBasis: 'consensus'
EOF
   
   cat <<EOF >>$DOMAIN_PATH/managed-domain.yaml
   Server:
        '$wlsServerName' :
           ListenPort: $MANAGEDSERVERPORT
           Notes: "$wlsServerName managed server"
           Cluster: "$wlsClusterName"
           Machine: "$hostName"
           SSL:
               Enabled: true
               ListenPort: $wlsManagedSSLPort
EOF
    
    cat <<EOF >>$DOMAIN_PATH/managed-domain.yaml
   SecurityConfiguration:
       NodeManagerUsername: "$wlsUserName"
       NodeManagerPasswordEncrypted: "$wlsPassword"
EOF
}


#This function to add machine for a given managed server
function create_machine_server()
{
    echo "Creating script to add machine and managed server $wlsServerName"
    cat <<EOF >$DOMAIN_PATH/add-node.py
import tempfile
import os
wlstOut = tempfile.mktemp(suffix="_wlstoutput.txt")
redirect(wlstOut,"false")


connect('$wlsUserName','$wlsPassword','t3://$wlsAdminURL')
try:
    cd('/Servers/$wlsServerName')
    stopRedirect()
    print 'Server $wlsServerName already exists. Removing it'
    domainRuntime()
    cd ('/ServerLifeCycleRuntimes/$wlsServerName')
    serverState=cmo.getState()
    if serverState=='RUNNING':
        cmo.shutdown()
    edit("$wlsServerName-remove")
    startEdit()
    editService.getConfigurationManager().removeReferencesToBean(getMBean('/MigratableTargets/$wlsServerName (migratable)'))
    cd('/')
    cmo.destroyMigratableTarget(getMBean('/MigratableTargets/$wlsServerName (migratable)'))
    editService.getConfigurationManager().removeReferencesToBean(getMBean('/Servers/$wlsServerName'))
    cd('/')
    cmo.destroyServer(getMBean('/Servers/$wlsServerName'))
    save()
    resolve()
    activate()
    destroyEditSession("$wlsServerName-remove")
except:
    stopRedirect()
    print 'Server does not exist create it here '
try:
    cd('/Machines/$hostName')
    stopRedirect()
    print 'Machine $hostName already exists. Removing it'
    edit("$hostName-remove")
    startEdit()
    editService.getConfigurationManager().removeReferencesToBean(getMBean('/Machines/$hostName'))
    cmo.destroyMachine(getMBean('/Machines/$hostName'))
    save()
    resolve()
    activate()
    destroyEditSession("$hostName-remove")
except:
    print 'Machine does not exist create it here '
edit("$hostName-add")
startEdit()
cd('/')
cmo.createMachine('$hostName')
cd('/Machines/$hostName/NodeManager/$hostName')
cmo.setListenPort(int($nmPort))
cmo.setListenAddress('$nmHost')
cmo.setNMType('ssl')
cd('/')
cmo.createServer('$wlsServerName')
cd('/Servers/$wlsServerName')
cmo.setCluster(getMBean('/Clusters/$wlsClusterName'))
cmo.setMachine(getMBean('/Machines/$hostName'))
cmo.setListenPort(int($wlsManagedPort))
cmo.setListenPortEnabled(true)
cd('/Servers/$wlsServerName/SSL/$wlsServerName')
cmo.setEnabled(true)
cmo.setListenPort(int($wlsManagedSSLPort))
cd('/Servers/$wlsServerName//ServerStart/$wlsServerName')
arguments = '-Dweblogic.security.SSL.ignoreHostnameVerification=true -Dweblogic.security.TrustKeyStore=DemoTrust -Dweblogic.Name=$wlsServerName -Dweblogic.management.server=http://$wlsAdminURL'
cmo.setArguments(arguments)
save()
resolve()
activate()
destroyEditSession("$hostName-add")
nmEnroll('$DOMAIN_PATH/$wlsDomainName','$DOMAIN_PATH/$wlsDomainName/nodemanager')
nmGenBootStartupProps('$wlsServerName')
disconnect()
os.remove(wlstOut)
exit()
EOF
}


# Create systemctl service for nodemanager
function create_nodemanager_service()
{
 echo "Setting CrashRecoveryEnabled true at $DOMAIN_PATH/$wlsDomainName/nodemanager/nodemanager.properties"
 sed -i.bak -e 's/CrashRecoveryEnabled=false/CrashRecoveryEnabled=true/g'  $DOMAIN_PATH/$wlsDomainName/nodemanager/nodemanager.properties
 chown -R $username:$groupname $DOMAIN_PATH/$wlsDomainName/nodemanager/nodemanager.properties*
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

#function to start managed server
function start_managed()
{

    echo "Starting managed server $wlsServerName"
    cat <<EOF >$DOMAIN_PATH/start-server.py
connect('$wlsUserName','$wlsPassword','t3://$wlsAdminURL')
try:
   start('$wlsServerName', 'Server')
except:
   print "Failed starting managed server $wlsServerName"
   dumpStack()
disconnect()
EOF
chown -R $username:$groupname $DOMAIN_PATH
runuser -l oracle -c ". $oracleHome/oracle_common/common/bin/setWlstEnv.sh; java $WLST_ARGS weblogic.WLST $DOMAIN_PATH/start-server.py"
if [[ $? != 0 ]]; then
  echo "Error : Failed in starting managed server $wlsServerName"
 
fi
}


#function to remove node py script
function create_removenode_script()
{
    echo "Creating remove node script "
    cat <<EOF >$DOMAIN_PATH/removenode.py
import tempfile
import os
wlstOut = tempfile.mktemp(suffix="_wlstoutput.txt")
redirect(wlstOut,"false")

try:
    connect('$wlsUserName','$wlsPassword','t3://$wlsAdminURL')
    stopRedirect()
    print "Successfully connected to the admin server"
except:
    stopRedirect()
    print "Error connecing to the admin server. Skipping the cleanup "
    exit()
domainRuntime()
cd ('/ServerLifeCycleRuntimes/$wlsServerName')
cmo.shutdown()
edit("$wlsServerName")
startEdit()
editService.getConfigurationManager().removeReferencesToBean(getMBean('/MigratableTargets/$wlsServerName (migratable)'))
cd('/')
cmo.destroyMigratableTarget(getMBean('/MigratableTargets/$wlsServerName (migratable)'))
editService.getConfigurationManager().removeReferencesToBean(getMBean('/Servers/$wlsServerName'))
cd('/')
cmo.destroyServer(getMBean('/Servers/$wlsServerName'))
editService.getConfigurationManager().removeReferencesToBean(getMBean('/Machines/$wlsServerName'))
cmo.destroyMachine(getMBean('/Machines/$wlsServerName'))
save()
resolve()
activate()
destroyEditSession("$wlsServerName")
disconnect()
os.remove(wlstOut)
exit() 
EOF
chown -R $username:$groupname $DOMAIN_PATH
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
wlsServerName=$MANAGEDSERVER
oracleHome="/u01/app/wls/install/oracle/middleware/oracle_home"
wlsManagedPort=$MANAGEDSERVERPORT
wlsManagedSSLPort=$MANAGEDSERVERSSLPORT
wlsAdminURL="$ADMINHOST:$ADMINSERVERPORT"
wlsClusterName=$CLUSTERNAME
nmHost=$LOCALHOSTIP
hostName=`hostname`
nmPort=$NMPORT

if [ ! -f $SCRIPTS/VAGRANT_PROVISIONER_MARKER ]
then 
    echo "Setting up managed node ......................."
    create_removenode_script
    create_managedSetup
    create_nodemanager_service
    enabledAndStartNodeManagerService
    start_managed
    touch $SCRIPTS/VAGRANT_PROVISIONER_MARKER
fi

