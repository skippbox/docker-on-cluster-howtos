#!/bin/sh

#Deploy the hatcheries of our swarm, the nodes which are going to host our containers

#Assuming you have exported the following values:

#export EXOSCALE_ACCOUNT_EMAIL=<your exoscale mail>
#export CLOUDSTACK_KEY=<your exoscale api key>
#export CLOUDSTACK_SECRET_KEY=<your exoscale api secret key>
#export CLOUDSTACK_ENDPOINT=https://api.exoscale.ch/compute

export N_WORKERS=1

blue=$(tput setaf 6)
green=$(tput setaf 2)
red=$(tput setaf 1)
normal=$(tput sgr0)

#Bring up our workers nodes
function create_hatchery() {
    printf "%s\n" "${green}Adding on an hatch to our swarm (swarm node)${normal}"
    docker-machine create --driver exoscale \
        --exoscale-api-key $CLOUDSTACK_KEY \
        --exoscale-api-secret-key $CLOUDSTACK_SECRET_KEY \
        --exoscale-instance-profile small \
        --exoscale-disk-size 10 \
        --exoscale-security-group swarm \
        --swarm \
        --swarm-discovery="consul://$(docker-machine ip overlord):8500" \
        --engine-opt="cluster-store=consul://$(docker-machine ip overlord):8500" \
        --engine-opt="cluster-advertise=eth0:2376" \
        --engine-label="type=node" \
        --swarm-opt="-experimental" \
        "$1" || { printf "%s\n" "${red}'No machine created (probably already exists)'${normal}" ; return 1; }
    printf "%s\n" "${blue}Hatch online${normal}"

    printf "%s\n" "${green}Running cadvisor to monitor this hatch${normal}"
    docker $(docker-machine config $1) run -d \
        -p 8888:8080 \
        --name=cadvisor-$1 \
        --restart=always \
        --volume=/var/run/docker.sock:/tmp/docker.sock \
        --volume=/:/rootfs:ro \
        --volume=/var/run:/var/run:rw \
        --volume=/sys:/sys:ro \
        --volume=/var/lib/docker/:/var/lib/docker:ro \
        google/cadvisor:latest &> /dev/null
    printf "%s\n" "${blue}Cadvisor launched${normal}"

    # printf "%s\n" "${green}Running registrator to communicate containers states to the overlord service discovery${normal}"
    # docker $(docker-machine config $1) run -d \
    #     --name=registrator-$1 \
    #     --restart=always \
    #     --volume=/var/run/docker.sock:/tmp/docker.sock \
    #     -h registrator \
    #     kidibox/registrator \
    #     -internal consul://$(docker-machine ip overlord):8500 &> /dev/null
    # printf "%s\n" "${blue}Registrator launched${normal}"

    docker-machine scp -r ../apps/webapp/conf-files/ $1: &> /dev/null

    # printf "%s\n" "${green}Updating kernel and rebooting${normal}"
    # docker-machine ssh $1 "sudo apt-get update &> /dev/null && sudo echo 'debconf debconf/frontend select Noninteractive' | sudo debconf-set-selections && sudo apt-get install -y linux-image-4.2.0-25-generic linux-image-extra-4.2.0-25-generic && sudo reboot"
    # printf "%s\n" "${blue}Done. Hatch ready to spawn containers.${normal}"
}

#Then create swarm hatcheries

for i in $(seq 1 "$N_WORKERS"); do
    hatch_name="swarm-hatch-$i"
    create_hatchery "$hatch_name" 
done

# sleep 15

printf "%s\n" "${green}Swarm state${normal}"
docker $(docker-machine config --swarm swarm-queen-primary) info

