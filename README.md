# Oracle WebLogic Server Cluster Vagrant project on VirtualBox
This directory contains Vagrant build files to provision a n-node Oracle WebLogic Server Cluster automatically, using Vagrant, an Oracle Linux 7 box and a shell provisioner

# Prerequisites
This project requires Vagrant and Oracle VM VirtualBox.
  - Install [Oracle VM VirtualBox](https://www.virtualbox.org/wiki/Downloads)
  - Install [Vagrant](https://vagrantup.com/)

## Getting Started 
1. Clone this repository git clone ... 
1. Download the desired WebLogic Server installer, JDK and deploy-tool zip and place them in directories under the installers directory - first time only
1. Run vagrant up (to provision one VM and start a single node with Admin Server only) or run "vagrant --c=2 up" (to provision 3 VMs to host the admin server and 2 managed servers in a cluster)
1. You can shut down the VM via the usual "vagrant halt" and the start it up again via "vagrant up".
   
## Customizing your WebLogic Server Domain 

 The following will create three OL7 VMs with the WebLogic admin server on the first VM and a two node cluster on other VM. 
```
  vagrant --c=2  up
```
## Commands to manage your environment

* Provision 3 VMs with admin server on one VM and two cluster members on the other two VMs
```
vagrant --c=2 up
```
* Accessing Admin Console - http://host-ip:7001/console
* Query state of all guest machines in your environment
```
vagrant --c=2 status 
```
* SSH into one of the running machines (In this example we ssh into the machine named "managed1")

```
vagrant --c=2 ssh managed1
```
* Scale out a domain by adding one or more machines to the environment (In the following example we add one more machine and server to the existing domain *--c=3*)

```
 vagrant --c=3 up --provision
```
* Gracefully Shut down one of the machines (In this example we shut down the machine named "managed3")

```
vagrant --c=3 halt managed3
```

* Start one of the machines that is in shut down state (In this example we start the machine named "managed3")

```
vagrant --c=3 up managed3
```
* Shutdown and destroy all resources associated with a machine

```
vagrant --c=3 destroy managed3
```
* Destroy all machines (shutdown and destroy al resources for all machines in the environment)

```
vagrant --c=3 destroy
```

### Optional WebLogic Server domain and cluster parameters to customize your environment
* --c  or --clusternodes : Number of WebLogic Server managed servers in the cluster (default - 0)
* --domain : Domain name (default - base_domain)
* --prefix : Managed Server prefix (default - managed)
* --wlsclustername : Name of the cluster (default - cluster1)
* --wlsuser : WebLogic Server admin username (default - weblogic)
* --wlspassword : WebLogic Server admin user password (default - welcome1)
* --asport : Listen port for the Admin Server  (default - 7001)
* --asportssl : SSL port for the Admin Server (defualt - 7002)
* --msport : Listen port for the first managed server. Port numbers increment for each additional managed server (default : 8001) 
* --msportssl : SSL Listen port for the first managed server. SSL Port numbers increment for each additional managed server (default : 8801)
* --nmport : NodeManager port (default : 5556) 
* --ipaddress : Listen address for the admin server (default : 10.0.0.250)

