# Oracle WebLogic Server Cluster Vagrant project on VirtualBox
This directory contains Vagrant build files to provision a n-node Oracle WebLogic Server Cluster automatically, using Vagrant, an Oracle Linux 7 box and a shell provisioner

# Prerequisites
This project requires Vagrant and Oracle VM VirtualBox.
  - Install [Oracle VM VirtualBox](https://www.virtualbox.org/wiki/Downloads)
  - Install [Vagrant](https://vagrantup.com/)


# Getting started

    * Clone this repository git clone ... 
    * Download the desired WebLogic Server installer, JDK and deploy-tool zip and place them in directories under the installers directory - first time only
    * Run vagrant up (to provision one VM and start a single node with Admin Server only) or run "vagrant --n=2 up" (to provision 3 VMs to host the admin server and 2 managed servers in a cluster)
    * You can shut down the VM via the usual "vagrant halt" and the start it up again via "vagrant up".

# Customizing your WebLogic Server Domain 

```sh
$ # the following will create three OL7 VMs with the WebLogic admin server on the first VM and a two node cluster on other VM. The domain name will be mydomain and the WLS cluster will be mycluster
$ 
$ vagrant --n=2 --domain=mydomain --clustername=mycluster  up
$ 
$  
$ 
$ 
```
