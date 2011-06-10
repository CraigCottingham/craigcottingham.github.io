#
# Cookbook Name:: debian_basic
# Recipe:: default
#
# Copyright 2010, fredz
#
# All rights reserved - Do Not Redistribute
#

case node[:platform]
when "debian", "ubuntu"
  %w( lsof iptables jwhois whois curl wget rsync jnettop nmap traceroute ethtool iproute iputils-ping netcat-openbsd tcpdump elinks lynx ).each do | pkg |
    package pkg do
      action :install
    end
  end
when "amazon"
  %w( lsof iptables jwhois curl wget rsync nmap traceroute ethtool iproute tcpdump elinks lynx ).each do | pkg |
    package pkg do
      action :install
    end
  end
end
