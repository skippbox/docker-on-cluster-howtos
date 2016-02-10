#!/bin/sh

# usage: networking.sh ip
# will open all the network port to administrate our demo infrastructure

IP=$1

# to swarm
cs authorizeSecurityGroupIngress protocol=TCP startPort=8888 endPort=8888 securityGroupName=swarm cidrList=$IP/32
cs authorizeSecurityGroupIngress protocol=TCP startPort=5000 endPort=5000 securityGroupName=swarm cidrList=$IP/32

# to consul
cs authorizeSecurityGroupIngress protocol=UDP startPort=53 endPort=53 securityGroupName=consul cidrList=$IP/32
cs authorizeSecurityGroupIngress protocol=TCP startPort=8500 endPort=8500 securityGroupName=consul cidrList=$IP/32
cs authorizeSecurityGroupIngress protocol=TCP startPort=9090 endPort=9090 securityGroupName=consul cidrList=$IP/32
cs authorizeSecurityGroupIngress protocol=TCP startPort=3000 endPort=3000 securityGroupName=consul cidrList=$IP/32
cs authorizeSecurityGroupIngress protocol=TCP startPort=5600 endPort=5600 securityGroupName=consul cidrList=$IP/32
