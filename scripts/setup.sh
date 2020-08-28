#!/bin/bash
set -e

hostfile=$HOSTFILE
SCRIPTS="/u01/app/scripts"
JDK_PATH="/u01/app/jdk"
WLS_PATH="/u01/app/wls"
WL_HOME="/u01/app/wls/install/oracle/middleware/oracle_home/wlserver"
BASE_DIR="/vagrant/installers"
DOMAIN_PATH="/u01/domains"
groupname="oracle"
username="oracle"
user_home_dir="/u01/oracle"
USER_GROUP=${groupname}
INSTALL_PATH="$WLS_PATH/install"

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


#Install Weblogic Server using Silent Installation Templates
function installWLS()
{
    # Using silent file templates create silent installation required files
    echo "Creating silent files for installation from silent file templates..."

    sed 's@\[INSTALL_PATH\]@'"$INSTALL_PATH"'@' ${SILENT_FILES_DIR}/response.template > ${SILENT_FILES_DIR}/response
    sed 's@\[INSTALL_PATH\]@'"$INSTALL_PATH"'@' ${SILENT_FILES_DIR}/oraInst.loc.template > ${SILENT_FILES_DIR}/oraInst.loc
    sed -i 's@\[GROUP\]@'"$USER_GROUP"'@' ${SILENT_FILES_DIR}/oraInst.loc

    echo "Created files required for silent installation at $SILENT_FILES_DIR"

    echo " Installing WLS ${WLS_JAR}"
    
    
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
      currentVer=`. $INSTALL_PATH/oracle/middleware/oracle_home/wlserver/server/bin/setWLSEnv.sh 1>&2 ; java weblogic.version |head -2| awk '{print $3;}'|tail -n +2`
      echo "Weblogic Server $currentVer Installation is successful"
    else

      echo_stderr "Installation is not successful"
      exit 1
    fi
}

function create_vm_banner()
{
    echo "Creating VM banner"
    cat <<EOF > /etc/motd 
    ***************************************************************
    This VM provides a pre-installed Oracle Home with 
    Oracle WebLogic Server $currentVer and JDK $jdkversion

    ORACLE_HOME /u01/app/wls/install/oracle/middleware/oracle_home
    JAVA_HOME   $JAVA_HOME
    DOMAIN_HOME /u01/domains/

    Switch to user oracle : sudo su - oracle
    ***************************************************************
EOF
}

function hostentries()
{
    echo "127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4">/etc/hosts
    echo "::1         localhost localhost.localdomain localhost6 localhost6.localdomain6">>/etc/hosts
    IFS=';' read -ra HOSTS <<< "$hostfile"
    for entry in "${HOSTS[@]}"; do
      echo "$entry">>/etc/hosts
    done
}

if [ ! -f $SCRIPTS/VAGRANT_PROVISIONER_MARKER ]
then 
    echo "Installing zip unzip wget rng-tools"
    yum install -y zip unzip wget rng-tools
    echo "Setting up rngd utils as a service"
    sudo systemctl enable rngd 
    sudo systemctl start rngd
    sudo systemctl status rngd

    #add oracle group and user
    echo "Adding oracle user and group..."
    mkdir /u01
    groupadd $groupname
    useradd -d ${user_home_dir} -g $groupname $username
    #create directory for setting up wls and jdk and to create domain 
    mkdir -p $JDK_PATH
    mkdir -p $WLS_PATH
    mkdir -p $DOMAIN_PATH
    mkdir -p $SCRIPTS

    chown -R $username:$groupname /u01/app
    chown -R $username:$groupname $DOMAIN_PATH

    if [ -e $BASE_DIR/wls/*.zip ]
    then
        cp $BASE_DIR/wls/*.zip $WLS_PATH/
        echo "unzipping wls install archive..."
        unzip -o $WLS_PATH/*.zip -d $WLS_PATH
    else
        cp $BASE_DIR/wls/*.jar $WLS_PATH/
    fi

    
    cp $BASE_DIR/jdk/jdk-*.tar.gz $JDK_PATH/

    echo "unzip deploy tool "
    unzip -o $BASE_DIR/deploytool/weblogic-deploy.zip -d $DOMAIN_PATH

    echo "extracting and setting up jdk..."
    tar -zxvf $JDK_PATH/jdk-*.tar.gz --directory $JDK_PATH
    rm $JDK_PATH/jdk-*.tar.gz

    chown -R $username:$groupname $JDK_PATH

    jdkversion=$(ls $JDK_PATH)

    echo "JDK Version is $jdkversion"

    export JAVA_HOME="$JDK_PATH/$jdkversion"
    export PATH="$JAVA_HOME/bin:$PATH"

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


    SILENT_FILES_DIR=$WLS_PATH/silent-template
    mkdir -p $SILENT_FILES_DIR
    chown -R $username:$groupname $WLS_PATH

    WLS_JAR=$(find $WLS_PATH -iname "*jar" -exec echo {} \;)


    mkdir -p $INSTALL_PATH
    chown -R $username:$groupname $INSTALL_PATH

    create_oraInstlocTemplate
    create_oraResponseTemplate
    installWLS
    create_vm_banner

fi 

hostentries

