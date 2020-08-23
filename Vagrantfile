# -*- mode: ruby -*-
# vi: set ft=ruby :

require 'getoptlong'



opts = GetoptLong.new(
    ["--clusternodes",   GetoptLong::OPTIONAL_ARGUMENT],
    ["--domain",         GetoptLong::OPTIONAL_ARGUMENT],
    ["--prefix",         GetoptLong::OPTIONAL_ARGUMENT],
    ["--wlsclustername", GetoptLong::OPTIONAL_ARGUMENT],
    ["--wlsuser",        GetoptLong::OPTIONAL_ARGUMENT],
    ["--wlspassword",    GetoptLong::OPTIONAL_ARGUMENT],
    ["--portas",         GetoptLong::OPTIONAL_ARGUMENT],
    ["--portms",         GetoptLong::OPTIONAL_ARGUMENT],
    ["--ipaddress",      GetoptLong::OPTIONAL_ARGUMENT],
    ["--portnm",         GetoptLong::OPTIONAL_ARGUMENT]
)

numberOfNodes=0
var_ms_port=8001
var_as_port=7001
var_ms_prefix='managed'
var_domain_name='base_domain'
var_cluster_name='cluster1'
var_wls_user="weblogic"
var_wls_pass="welcome1"
var_admin_ip="10.0.0.250"
var_nm_port=5556
servers = {}
hostfile = ""


#validate the WebLogic password policy
if ! /\d/.match(var_wls_pass)
    puts "ERROR : The WebLogic domain password should contain a number and should be at least 8 characters long"
    exit
end

if var_wls_pass.length < 8
    puts "ERROR : The WebLogic domain password should contain a number and should be at least 8 characters long"
    exit 
end

# Installing the vagrant-proxyconf plugin
unless Vagrant.has_plugin?("vagrant-proxyconf")
    puts 'Installing vagrant-proxyconf Plugin'
    system('vagrant plugin install vagrant-proxyconf')
end
  

opts.ordering=(GetoptLong::REQUIRE_ORDER)

opts.each do |opt, arg|
  case opt
    when '--clusternodes'
        numberOfNodes= Integer(arg)
    when '--domain'
        var_domain_name=arg
    when '--prefix'
        var_ms_prefix=arg
    when '--wlsclustername'
        var_cluster_name=arg
    when '--wlsuser'
        var_wls_user=arg
    when '--wlspassword'
        var_wls_pass=arg
    when '--portas'
        var_as_port= Integer(arg)
    when '--portms'
        var_ms_port= Integer(arg)
    when '--ipaddress'
        var_admin_ip= arg   
    when '--portnm'
        var_nm_port= Integer(arg) 
    end
end

#puts "\n"
#puts "Number of Nodes , #{numberOfNodes}"
#puts "\n"
#puts "Domain name , #{var_domain_name}"
#puts "\n"
#puts "MS Prefix , #{var_ms_prefix}"
#puts "\n"
#puts "MS Port , #{var_ms_port}"
#puts "\n"
#puts "AS Port , #{var_as_port}"
#puts "\n"



ip = IPAddr.new(var_admin_ip)
(0..numberOfNodes).each do |i|
    i == 0 ? servers["admin"] =ip.to_s  : servers["managed#{i}"] =ip.to_s 
    ip = ip.succ
end


servers.each do |servername, ipaddress|
    hostfile.concat(ipaddress)
    hostfile.concat("  ")
    hostfile.concat(servername)
    hostfile.concat(";")
end


######## Begin main vagrant file
# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

# # Box metadata location and box name
BOX_URL = "https://oracle.github.io/vagrant-projects/boxes"
BOX_NAME = "oraclelinux/7"

NODE_COUNT=numberOfNodes 

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

no_proxy_list =""


if Vagrant.has_plugin?("vagrant-proxyconf")
#    puts "getting Proxy Configuration from Host..."
if ENV["http_proxy"]
#    puts "http_proxy: " + ENV["http_proxy"]
    config.proxy.http     = ENV["http_proxy"]
end
if ENV["https_proxy"]
#    puts "https_proxy: " + ENV["https_proxy"]
    config.proxy.https    = ENV["https_proxy"]
end
if ENV["no_proxy"]
    no_proxy_list.concat(ENV["no_proxy"])
    servers.each do |servername, ipaddress|
        no_proxy_list.concat(",")
        no_proxy_list.concat(ipaddress)
    end
#    puts "no_proxy: " + no_proxy_list
    config.proxy.no_proxy = no_proxy_list 
end
end

config.vm.define "admin" do |subconfig|
    subconfig.vm.box = BOX_NAME
    subconfig.vm.box_url = "#{BOX_URL}/#{BOX_NAME}.json"
    subconfig.vm.hostname = "admin"
    subconfig.vm.provider :virtualbox do |vb| 
	vb.memory = 2300
        vb.cpus   = 2
    end
    

    subconfig.vm.network :private_network, ip: servers.fetch("admin")    
    subconfig.vm.network "forwarded_port", guest: var_as_port, host: var_as_port
    subconfig.vm.provision "shell", path: "scripts/createadmin.sh", env: {
        "ADMINHOST"        => servers.fetch("admin"),
        "ADMINSERVERPORT"  => var_as_port,
        "DOMAINNAME"       => var_domain_name,
        "CLUSTERNAME"      => var_cluster_name,
        "WLUSER"           => var_wls_user,
        "WLPASS"           => var_wls_pass,
        "NMPORT"           => var_nm_port
    } 

end
  
(1..NODE_COUNT).each do |i|
config.vm.define "managed#{i}" do |subconfig|
    subconfig.vm.box = BOX_NAME
    subconfig.vm.box_url = "#{BOX_URL}/#{BOX_NAME}.json" 
    subconfig.vm.hostname = "managed#{i}" 
    subconfig.vm.provider :virtualbox do |vb|
        vb.memory = 2300
        vb.cpus   = 2
    end 
    subconfig.trigger.before :destroy do |trigger|
        trigger.name = "Before destroy trigger"
        trigger.info = "Shutting down server and remove server and machine from configuration before destroy"
        trigger.info = "Please ensure the VM is up and running"
        trigger.run_remote = {path: "scripts/destroy.sh"} 
    end
    subconfig.vm.network :private_network, ip: servers.fetch("managed#{i}")
    subconfig.vm.network "forwarded_port", guest: var_ms_port, host: var_ms_port 
    subconfig.vm.provision "shell", path: "scripts/createmanaged.sh", env: {
	    "ADMINHOST"        => servers.fetch("admin"),
        "MANAGEDSERVER"    => "#{var_ms_prefix}".concat("#{i}"), 
        "ADMINSERVERPORT"  => var_as_port,
        "MANAGEDSERVERPORT"=> var_ms_port ,
        "LOCALHOSTIP"      => servers.fetch("managed#{i}"),
        "DOMAINNAME"       => var_domain_name,
        "CLUSTERNAME"      => var_cluster_name,
        "WLUSER"           => var_wls_user,
        "WLPASS"           => var_wls_pass,
        "NMPORT"           => var_nm_port
    }
    var_ms_port=var_ms_port.next
end
end

config.vm.provision "shell", path: "scripts/setup.sh", env: {
    "HOSTFILE"        => hostfile
}

end

