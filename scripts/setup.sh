#!/bin/bash

set -e



shiphomeurl=$WLSURL
jdkurl=$JAVAURL
wlsversion=$VERSIONWLS
jdkversion=$VERSIONJDK


#Function to create Weblogic Installation Location Template File for Silent Installation
function create_oraInstlocTemplate()
{
    echo "creating Install Location Template..."

    cat <<EOF >$WLS_PATH/silent-template/oraInst.loc.template
inventory_loc=[INSTALL_PATH]
inst_group=[GROUP]
EOF
}

#Function to create Weblogic Installation Response Template File for Silent Installation
function create_oraResponseTemplate()
{

    echo "creating Response Template..."

    cat <<EOF >$WLS_PATH/silent-template/response.template
[ENGINE]

#DO NOT CHANGE THIS.
Response File Version=1.0.0.0.0

[GENERIC]

#Set this to true if you wish to skip software updates
DECLINE_AUTO_UPDATES=false

#My Oracle Support User Name
MOS_USERNAME=

#My Oracle Support Password
MOS_PASSWORD=<SECURE VALUE>

#If the Software updates are already downloaded and available on your local system, then specify the path to the directory where these patches are available and set SPECIFY_DOWNLOAD_LOCATION to true
AUTO_UPDATES_LOCATION=

#Proxy Server Name to connect to My Oracle Support
SOFTWARE_UPDATES_PROXY_SERVER=

#Proxy Server Port
SOFTWARE_UPDATES_PROXY_PORT=

#Proxy Server Username
SOFTWARE_UPDATES_PROXY_USER=

#Proxy Server Password
SOFTWARE_UPDATES_PROXY_PASSWORD=<SECURE VALUE>

#The oracle home location. This can be an existing Oracle Home or a new Oracle Home
ORACLE_HOME=[INSTALL_PATH]/oracle/middleware/oracle_home

#Set this variable value to the Installation Type selected. e.g. WebLogic Server, Coherence, Complete with Examples.
INSTALL_TYPE=WebLogic Server

#Provide the My Oracle Support Username. If you wish to ignore Oracle Configuration Manager configuration provide empty string for user name.
MYORACLESUPPORT_USERNAME=

#Provide the My Oracle Support Password
MYORACLESUPPORT_PASSWORD=<SECURE VALUE>

#Set this to true if you wish to decline the security updates. Setting this to true and providing empty string for My Oracle Support username will ignore the Oracle Configuration Manager configuration
DECLINE_SECURITY_UPDATES=true

#Set this to true if My Oracle Support Password is specified
SECURITY_UPDATES_VIA_MYORACLESUPPORT=false

#Provide the Proxy Host
PROXY_HOST=

#Provide the Proxy Port
PROXY_PORT=

#Provide the Proxy Username
PROXY_USER=

#Provide the Proxy Password
PROXY_PWD=<SECURE VALUE>

#Type String (URL format) Indicates the OCM Repeater URL which should be of the format [scheme[Http/Https]]://[repeater host]:[repeater port]
COLLECTOR_SUPPORTHUB_URL=


EOF
}

#Function to create Weblogic Uninstallation Response Template File for Silent Uninstallation
function create_oraUninstallResponseTemplate()
{
    echo "creating Uninstall Response Template..."

    cat <<EOF >$WLS_PATH/silent-template/uninstall-response.template
[ENGINE]

#DO NOT CHANGE THIS.
Response File Version=1.0.0.0.0

[GENERIC]

#This will be blank when there is nothing to be de-installed in distribution level
SELECTED_DISTRIBUTION=WebLogic Server~[WLSVER]

#The oracle home location. This can be an existing Oracle Home or a new Oracle Home
ORACLE_HOME=[INSTALL_PATH]/oracle/middleware/oracle_home/

EOF
}

#Install Weblogic Server using Silent Installation Templates
function installWLS()
{
    # Using silent file templates create silent installation required files
    echo "Creating silent files for installation from silent file templates..."

    sed 's@\[INSTALL_PATH\]@'"$INSTALL_PATH"'@' ${SILENT_FILES_DIR}/uninstall-response.template > ${SILENT_FILES_DIR}/uninstall-response
    sed -i 's@\[WLSVER\]@'"$WLS_VER"'@' ${SILENT_FILES_DIR}/uninstall-response
    sed 's@\[INSTALL_PATH\]@'"$INSTALL_PATH"'@' ${SILENT_FILES_DIR}/response.template > ${SILENT_FILES_DIR}/response
    sed 's@\[INSTALL_PATH\]@'"$INSTALL_PATH"'@' ${SILENT_FILES_DIR}/oraInst.loc.template > ${SILENT_FILES_DIR}/oraInst.loc
    sed -i 's@\[GROUP\]@'"$USER_GROUP"'@' ${SILENT_FILES_DIR}/oraInst.loc

    echo "Created files required for silent installation at $SILENT_FILES_DIR"

    export UNINSTALL_SCRIPT=$INSTALL_PATH/oracle/middleware/oracle_home/oui/bin/deinstall.sh
    if [ -f "$UNINSTALL_SCRIPT" ]
    then
            currentVer=`. $INSTALL_PATH/oracle/middleware/oracle_home/wlserver/server/bin/setWLSEnv.sh 1>&2 ; java weblogic.version |head -2`
            echo "#########################################################################################################"
            echo "Uninstalling already installed version :"$currentVer
            runuser -l oracle -c "$UNINSTALL_SCRIPT -silent -responseFile ${SILENT_FILES_DIR}/uninstall-response"
            sudo rm -rf $INSTALL_PATH/*
            echo "#########################################################################################################"
    fi

    echo "---------------- Installing WLS ${WLS_JAR} ----------------"
    
    
    if [[ "$jdkversion" =~ ^jdk1.8* ]]
    then
    
    echo $JAVA_HOME/bin/java -d64  -jar  ${WLS_JAR} -silent -invPtrLoc ${SILENT_FILES_DIR}/oraInst.loc -responseFile ${SILENT_FILES_DIR}/response -novalidation
    runuser -l oracle -c "$JAVA_HOME/bin/java -d64 -jar  ${WLS_JAR} -silent -invPtrLoc ${SILENT_FILES_DIR}/oraInst.loc -responseFile ${SILENT_FILES_DIR}/response -novalidation"
    
    else 

    echo $JAVA_HOME/bin/java -jar  ${WLS_JAR} -silent -invPtrLoc ${SILENT_FILES_DIR}/oraInst.loc -responseFile ${SILENT_FILES_DIR}/response -novalidation
    runuser -l oracle -c "$JAVA_HOME/bin/java -jar  ${WLS_JAR} -silent -invPtrLoc ${SILENT_FILES_DIR}/oraInst.loc -responseFile ${SILENT_FILES_DIR}/response -novalidation"
    
    fi

    # Check for successful installation and version requested
    if [[ $? == 0 ]];
    then
      echo "Weblogic Server Installation is successful"
    else

      echo_stderr "Installation is not successful"
      exit 1
    fi
    echo "#########################################################################################################"

}


echo "=================================== START OF SETUP SCRIPT ====================="
echo "=================================== SETUP SCRIPT - add user and group ====================="

#add oracle group and user
echo "Adding oracle user and group..."
groupname="oracle"
username="oracle"
user_home_dir="/u01/oracle"
USER_GROUP=${groupname}
mkdir /u01
groupadd $groupname
useradd -d ${user_home_dir} -g $groupname $username

echo "=================================== SETUP SCRIPT - create directories ====================="

JDK_PATH="/u01/app/jdk"
WLS_PATH="/u01/app/wls"
WL_HOME="/u01/app/wls/install/oracle/middleware/oracle_home/wlserver"
BASE_DIR="/vagrant/installers"
DOMAIN_PATH="/u01/domains"

#create directory for setting up wls and jdk and to create domain 
mkdir -p $JDK_PATH
mkdir -p $WLS_PATH
mkdir -p $DOMAIN_PATH

chown -R $username:$groupname /u01/app
chown -R $username:$groupname $DOMAIN_PATH

cp $BASE_DIR/fmw_*.zip $WLS_PATH/
cp $BASE_DIR/jdk-*.tar.gz $JDK_PATH/

echo "unzip deploy tool "
unzip -o $BASE_DIR/weblogic-deploy.zip -d $DOMAIN_PATH

echo "extracting and setting up jdk..."
tar -zxvf $JDK_PATH/jdk-*.tar.gz --directory $JDK_PATH
chown -R $username:$groupname $JDK_PATH

export JAVA_HOME=$JDK_PATH/$jdkversion
export PATH=$JAVA_HOME/bin:$PATH

echo "JAVA_HOME set to $JAVA_HOME"
echo "PATH set to $PATH"

java -version

if [ $? == 0 ];
then
    echo "JAVA HOME set succesfully."
else
    echo_stderr "Failed to set JAVA_HOME. Please check logs and re-run the setup"
    exit 1
fi

echo "unzipping wls install archive..."
unzip -o $WLS_PATH/fmw_*.zip -d $WLS_PATH

SILENT_FILES_DIR=$WLS_PATH/silent-template
mkdir -p $SILENT_FILES_DIR
chown -R $username:$groupname $WLS_PATH

INSTALL_PATH="$WLS_PATH/install"
WLS_JAR=$WLS_PATH"/fmw_"$wlsversion"_wls.jar"

mkdir -p $INSTALL_PATH
chown -R $username:$groupname $INSTALL_PATH

create_oraInstlocTemplate
create_oraResponseTemplate
create_oraUninstallResponseTemplate

installWLS
