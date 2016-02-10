#!/bin/sh

#Deploy the queen of our swarm, the node which act as primary swarm master, scheduling our container on the hatcheries

#Assuming you have exported the following values:

#export EXOSCALE_ACCOUNT_EMAIL=<your exoscale mail>
#export CLOUDSTACK_KEY=<your exoscale api key>
#export CLOUDSTACK_SECRET_KEY=<your exoscale api secret key>
#export CLOUDSTACK_ENDPOINT=https://api.exoscale.ch/compute

blue=$(tput setaf 6)
green=$(tput setaf 2)
red=$(tput setaf 1)
normal=$(tput sgr0)

printf "%s\n" "${green}Creating the queen of our swarm (swarm master primary)${normal}"
docker-machine create --driver exoscale \
        --exoscale-api-key $CLOUDSTACK_KEY \
        --exoscale-api-secret-key $CLOUDSTACK_SECRET_KEY \
        --exoscale-instance-profile micro \
        --exoscale-disk-size 10 \
        --exoscale-security-group swarm \
        --swarm \
        --swarm-master \
        --swarm-discovery="consul://$(docker-machine ip overlord):8500" \
        --engine-opt="cluster-store=consul://$(docker-machine ip overlord):8500" \
        --engine-opt="cluster-advertise=eth0:2376" \
        --engine-label="type=master" \
        swarm-queen-primary || { printf "%s\n" "${red}'Machine creation failed :-/ Doing nothing'${normal}" ;  exit 1; }
printf "%s\n" "${blue}Queen online${normal}"

printf "%s\n" "${green}Running cadvisor to monitor the queen${normal}"
docker $(docker-machine config swarm-queen-primary) run -d \
      -p 8888:8080 \
      --name=cadvisor-queen \
      --restart=always \
      --volume=/var/run/docker.sock:/tmp/docker.sock \
      --volume=/:/rootfs:ro \
      --volume=/var/run:/var/run:rw \
      --volume=/sys:/sys:ro \
      --volume=/var/lib/docker/:/var/lib/docker:ro \
      google/cadvisor:latest &> /dev/null
printf "%s\n" "${blue}Cadvisor online${normal}"

# printf "%s\n" "${green}Running registrator to communicate containers states to the overlord service discovery${normal}"
# docker $(docker-machine config swarm-queen-primary) run -d \
#     --name=registrator-queen-primary \
#     --restart=always \
#     --volume=/var/run/docker.sock:/tmp/docker.sock \
#     -h registrator \
#     kidibox/registrator \
#     -internal consul://$(docker-machine ip overlord):8500 &> /dev/null
# printf "%s\n" "${blue}Registrator launched${normal}"

# # Let's run the consul that will act the dns server and kv store inside our overlay network
# printf "%s\n" "${green}Running consul as overlay network service registry and dns server${normal}"
# docker $(docker-machine config swarm-queen-primary) run --name consul \
#     --restart=always  \
#     -p 8500:8500  \
#     -p 53:53/udp  \
#     -h consul \
#     -d progrium/consul -server -bootstrap -ui-dir /ui

docker-machine scp -r ../conf-files/ swarm-queen-primary: &> /dev/null

# printf "%s\n" "${green}Updating kernel and rebooting${normal}"
# docker-machine ssh swarm-queen-primary "sudo apt-get update &> /dev/null && sudo echo 'debconf debconf/frontend select Noninteractive' | sudo debconf-set-selections && sudo apt-get install -y linux-image-4.2.0-25-generic linux-image-extra-4.2.0-25-generic && sudo reboot"

#wait for reboot
# sleep 15

printf "%s\n" "${blue}Swarm state${normal}"
docker $(docker-machine config --swarm swarm-queen-primary) info