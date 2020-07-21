# -*- mode: ruby -*-
# vi: set ft=ruby :

require 'getoptlong'


opts = GetoptLong.new(
    ["--nodes", GetoptLong::OPTIONAL_ARGUMENT]
)

numberOfNodes=3

opts.ordering=(GetoptLong::REQUIRE_ORDER)

opts.each do |opt, arg|
  case opt
    when '--nodes'
      numberOfNodes= Integer(arg)
  end
  print "\n"
  print "Number of Nodes , #{numberOfNodes}"
  print "\n"
end



######## Begin main vagrant file


BOX_IMAGE = "oraclelinux/7"
BOX_URL = "https://oracle.github.io/vagrant-projects/boxes/oraclelinux/7.json"
NODE_COUNT=numberOfNodes 
var_user_name ="Jacob"
shiphomeurl="http://download.oracle.com/otn/nt/middleware/12c/12213/fmw_12.2.1.3.0_wls_Disk1_1of1.zip"
jdkurl="https://download.oracle.com/otn/java/jdk/8u131-b11/d54c1d3a095b4ff2b6607d096fa80163/jdk-8u131-linux-x64.tar.gz"
wlsversion="12.2.1.4.0"
jdkversion="jdk1.8.0_251"


Vagrant.configure("2") do |config|




if Vagrant.has_plugin?("vagrant-proxyconf")
    puts "getting Proxy Configuration from Host..."
if ENV["http_proxy"]
    puts "http_proxy: " + ENV["http_proxy"]
    config.proxy.http     = ENV["http_proxy"]
end
if ENV["https_proxy"]
    puts "https_proxy: " + ENV["https_proxy"]
    config.proxy.https    = ENV["https_proxy"]
end
if ENV["no_proxy"]
    no_proxy_list.concat(ENV["no_proxy"])
    no_proxy_list.concat(",")
    no_proxy_list.concat("10.0.0.10")
    (1..NODE_COUNT).each do |i|
        no_proxy_list.concat(",")
        no_proxy_list.concat("10.0.0.#{i + 10}")
    end
    puts "no_proxy: " + no_proxy_list
    config.proxy.no_proxy = no_proxy_list 
end
end

config.vm.define "admin" do |subconfig|
subconfig.vm.box = BOX_IMAGE
subconfig.vm.box_url = BOX_URL
#subconfig.name ="admin"
subconfig.vm.hostname = "admin"
subconfig.vm.network :private_network, ip: "10.0.0.10"
subconfig.vm.provision "shell", inline: <<-SHELL
    echo "H E L L O     W O R L D ============> ADMIN NODE"    
    SHELL
subconfig.vm.provision "shell", path: "scripts/createadmin.sh", env: {
"ADMINURL"  => "10.0.0.10"
} 

end
  
(1..NODE_COUNT).each do |i|
config.vm.define "managed#{i}" do |subconfig|
    subconfig.vm.box = BOX_IMAGE
    subconfig.vm.box_url = BOX_URL

    subconfig.vm.hostname = "managed#{i}"
    subconfig.vm.network :private_network, ip: "10.0.0.#{i + 10}"
    subconfig.vm.provision "shell", inline: <<-SHELL
    echo "H E L L O     W O R L D ==========> MANAGED NODE"
    echo "H E L L O     W O R L D  #{i}" 
    SHELL
end
end

config.vm.provision "shell", inline: <<-SHELL
    echo "Hello World"
    cat >> /etc/motd << EOF
*******************************************************
**                 Hello there,                      **
**      Welcome to a VM that was customized with     **
**            the vagrant shell provisioner          **
*******************************************************
EOF
SHELL

config.vm.provision "shell", inline: <<-SHELL
    echo "Installing zip unzip wget rng-tools"
    yum install -y zip unzip wget rng-tools

    echo "Setting up rngd utils as a service"
    systemctl enable rngd 
    systemctl status rngd
    systemctl start rngd
    systemctl status rngd

SHELL

# Enable provisioning with a shell script

#   config.vm.provision :shell, inline: "echo 'source /vagrant/scripts/setenv.sh' > /etc/profile.d/sa-environment.sh", :run => 'always'
   config.vm.provision "shell", path: "scripts/setup.sh", env: {
         "NAME"         => var_user_name,
         "WLSURL"       => shiphomeurl,
	 "JAVAURL"      => jdkurl,
	 "VERSIONWLS"   => wlsversion,
	 "VERSIONJDK"   => jdkversion
   }

end

