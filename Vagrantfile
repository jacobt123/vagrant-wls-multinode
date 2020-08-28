# -*- mode: ruby -*-
# vi: set ft=ruby :

require 'getoptlong'
require 'logger'



opts = GetoptLong.new(
    ["--clusternodes",   GetoptLong::OPTIONAL_ARGUMENT],
    ["--domain",         GetoptLong::OPTIONAL_ARGUMENT],
    ["--prefix",         GetoptLong::OPTIONAL_ARGUMENT],
    ["--wlsclustername", GetoptLong::OPTIONAL_ARGUMENT],
    ["--wlsuser",        GetoptLong::OPTIONAL_ARGUMENT],
    ["--wlspassword",    GetoptLong::OPTIONAL_ARGUMENT],
    ["--asport",         GetoptLong::OPTIONAL_ARGUMENT],
    ["--asportssl",      GetoptLong::OPTIONAL_ARGUMENT],
    ["--msport",         GetoptLong::OPTIONAL_ARGUMENT],
    ["--msportssl",      GetoptLong::OPTIONAL_ARGUMENT],
    ["--ipaddress",      GetoptLong::OPTIONAL_ARGUMENT],
    ["--nmport",         GetoptLong::OPTIONAL_ARGUMENT],
    ["--verbose",        GetoptLong::OPTIONAL_ARGUMENT]
)

logger = Logger.new(STDOUT)
logger.datetime_format = "%Y-%m-%d %H:%M:%S"
logger.level = Logger::INFO

numberOfNodes=0
var_ms_port=8001
var_as_port=7001
var_ms_sslport=8801
var_as_sslport=7002
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
    logger.info "ERROR : The WebLogic domain password should contain a number and should be at least 8 characters long"
    exit
end

if var_wls_pass.length < 8
    logger.info "ERROR : The WebLogic domain password should contain a number and should be at least 8 characters long"
    exit 
end

# Check if the jdk exists in the appropriate directory
if Dir["./installers/jdk/*tar.gz"].empty?
    logger.info 'Could not find the JDK in the ./installers/jdk directory '
    exit 
end

# Check if the deploy tool zip exists in the appropriate directory
if Dir["./installers/deploytool/*.zip"].empty?
    logger.info 'Could not find the weblogic-deploy.zip in the ./installers/deploytool directory '
    exit 
end

# Check if the WebLogic Server installer exists in the appropriate directory
if Dir["./installers/wls/*.zip"].empty? && Dir["./installers/wls/*.jar"].empty? 
    logger.info 'Could not find the WebLogic Server installer in the ./installers/wls directory '
    exit 
end

# Installing the vagrant-proxyconf plugin
unless Vagrant.has_plugin?("vagrant-proxyconf")
    logger.info 'Installing vagrant-proxyconf Plugin'
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
    when '--asportssl'
        var_as_sslport= Integer(arg)
    when '--msportssl'
        var_ms_sslport= Integer(arg)
    when '--asport'
        var_as_port= Integer(arg)
    when '--msport'
        var_ms_port= Integer(arg)
    when '--ipaddress'
        var_admin_ip= arg   
    when '--nmport'
        var_nm_port= Integer(arg) 
    when '--verbose'
        logger.level = Logger::DEBUG 
    end
end

logger.debug "\n"
logger.debug "Number of cluster nodes , #{numberOfNodes}" if numberOfNodes > 0
logger.debug "WLS Admin user , #{var_wls_user}"
logger.debug "WLS Admin user password, #{var_wls_pass}"
logger.debug "Domain name , #{var_domain_name}"
logger.debug "Cluster name , #{var_cluster_name}" if numberOfNodes > 0
logger.debug "Admin Server IP , #{var_admin_ip}"
logger.debug "MS Prefix , #{var_ms_prefix}" if numberOfNodes > 0
logger.debug "MS Port , #{var_ms_port}" if numberOfNodes > 0
logger.debug "MS SSL Port , #{var_ms_sslport}" if numberOfNodes > 0
logger.debug "AS Port , #{var_as_port}"
logger.debug "AS SSL Port , #{var_as_sslport}"
logger.debug "NM Port , #{var_nm_port}"
logger.debug "\n"



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
    logger.debug "getting Proxy Configuration from Host..."
if ENV["http_proxy"]
    logger.debug "http_proxy: " + ENV["http_proxy"]
    config.proxy.http     = ENV["http_proxy"]
end
if ENV["https_proxy"]
    logger.debug "https_proxy: " + ENV["https_proxy"]
    config.proxy.https    = ENV["https_proxy"]
end
if ENV["no_proxy"]
    no_proxy_list.concat(ENV["no_proxy"])
    servers.each do |servername, ipaddress|
        no_proxy_list.concat(",")
        no_proxy_list.concat(ipaddress)
    end
    logger.debug "no_proxy: " + no_proxy_list
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
    subconfig.vm.network "forwarded_port", guest: var_as_sslport, host: var_as_sslport
    subconfig.vm.provision "shell", path: "scripts/createadmin.sh", env: {
        "ADMINHOST"              => servers.fetch("admin"),
        "ADMINSERVERPORT"        => var_as_port,
        "DOMAINNAME"             => var_domain_name,
        "CLUSTERNAME"            => var_cluster_name,
        "WLUSER"                 => var_wls_user,
        "WLPASS"                 => var_wls_pass,
        "NMPORT"                 => var_nm_port
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
    subconfig.vm.network :private_network, ip: servers.fetch("managed#{i}")
    subconfig.vm.network "forwarded_port", guest: var_ms_port, host: var_ms_port 
    subconfig.vm.network "forwarded_port", guest: var_ms_sslport, host: var_ms_sslport
    subconfig.vm.provision "shell", path: "scripts/createmanaged.sh", env: {
	    "ADMINHOST"              => servers.fetch("admin"),
        "MANAGEDSERVER"          => "#{var_ms_prefix}".concat("#{i}"), 
        "ADMINSERVERPORT"        => var_as_port,
        "MANAGEDSERVERPORT"      => var_ms_port ,
        "MANAGEDSERVERSSLPORT"   => var_ms_sslport ,
        "LOCALHOSTIP"            => servers.fetch("managed#{i}"),
        "DOMAINNAME"             => var_domain_name,
        "CLUSTERNAME"            => var_cluster_name,
        "WLUSER"                 => var_wls_user,
        "WLPASS"                 => var_wls_pass,
        "NMPORT"                 => var_nm_port
    }
    var_ms_port=var_ms_port.next
    var_ms_sslport=var_ms_sslport.next
end
end

config.vm.provision "shell", path: "scripts/setup.sh", env: {
        "HOSTFILE"               => hostfile
}

end

