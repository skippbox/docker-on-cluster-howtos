#How to create a swarm cluster on Exoscale

This document describes the necessary steps to create a swarm cluster on (Exoscale)|[https://exoscale.ch] cloud provider.
Make sure you have Docker 1.9, Machine 0.5, and Compose 1.5 installed.
See [http://docs.docker.com] to access the installation documentation of docker-machine for your platform.

##Setting up cs

To interact with Exoscale cloudstack API we will need to use the (cs)|[https://github.com/exoscale/cs] command line tool.
You will need to get your api keys from you Exoscale account (accessible from the exoscale dashboard in Account > Api Keys).
Then we will need to export those values in your shell:

    $ export EXOSCALE_ACCOUNT_EMAIL=<your exoscale mail>
    $ export CLOUDSTACK_KEY=<your exoscale api key>
    $ export CLOUDSTACK_SECRET_KEY=<your exoscale api secret key>
    $ export CLOUDSTACK_ENDPOINT=https://api.exoscale.ch/compute

##Setting up the Swarm !

###Creating a discovery service on a machine out of the cluster

Docker engines need a Key-value store to store informations. This is used by the swarm master to gather informations about the nodes joining the managed cluster. We are consul for this purpose, but alternatives exists, like etcd or zookeeper.

    $ docker-machine create --driver exoscale \
        --exoscale-api-key $CLOUDSTACK_KEY \
        --exoscale-api-secret-key $CLOUDSTACK_SECRET_KEY \
        --exoscale-instance-profile tiny \
        --exoscale-disk-size 10 \
        --exoscale-security-group consul \
        consul

Administrate this instance using docker-machine with:

    $ eval $(docker-machine env consul)

Start a consul container with:

    $ docker run --name consul \
    --restart=always  \
    -p 8400:8400  \
    -p 8500:8500  \
    -p 53:53/udp  \
    -h consul \
    -d progrium/consul -server -bootstrap-expect 1 -ui-dir /ui

Finally add security rules to allow our swarm nodes to communicate with the consul server on the port tcp/8500 (optionnaly udp/53).
    
    $ cs authorizeSecurityGroupIngress protocol=TCP startPort=8500 endPort=8500 securityGroupName=consul usersecuritygrouplist[0].account=$EXOSCALE_ACCOUNT_EMAIL usersecuritygrouplist[0].group=swarm

Of course you can also authorize your public ip address to access the consul web ui with something like:

    $ cs authorizeSecurityGroupIngress protocol=TCP startPort=8500 endPort=8500 securityGroupName=consul cidrList=<your ip address/32>

Or if you'd rather use dns queries:

    $ cs authorizeSecurityGroupIngress protocol=UDP startPort=53 endPort=53 securityGroupName=consul cidrList=<your ip address/32>

###Creating the swarm master

We need instances on which to install swarm. Let's first create the master with:
    
    $ docker-machine create --driver exoscale \
        --exoscale-api-key $CLOUDSTACK_KEY \
        --exoscale-api-secret-key $CLOUDSTACK_SECRET_KEY \
        --exoscale-instance-profile small \
        --exoscale-disk-size 10 \
        --exoscale-image ubuntu-14.04 \
        --exoscale-security-group swarm \
        --swarm \
        --swarm-master \
        --swarm-discovery="consul://$(docker-machine ip consul):8500" \
        --engine-opt="cluster-store=consul://$(docker-machine ip consul):8500" \
        --engine-opt="cluster-advertise=eth0:2376" \
        swarm-master

To connect to the master via ssh use:
    
    $ docker-machine ssh swarm-master

Administrate the cluster using docker-machine with: (note the `--swarm`):

    $ eval $(docker-machine env --swarm swarm-master)

###Creating a swarm node

    $ docker-machine create --driver exoscale \
        --exoscale-api-key $CLOUDSTACK_KEY \
        --exoscale-api-secret-key $CLOUDSTACK_SECRET_KEY \
        --exoscale-instance-profile small \
        --exoscale-image ubuntu-14.04 \
        --exoscale-disk-size 10 \
        --exoscale-security-group swarm \
        --swarm \
        --swarm-discovery="consul://$(docker-machine ip consul):8500" \
        --engine-opt="cluster-store=consul://$(docker-machine ip consul):8500" \
        --engine-opt="cluster-advertise=eth0:2376" \
        swarm-node-1

Of course you can create as many nodes as needed, simply increments the digit in their name.

More driver options are available: [https://docs.docker.com/machine/drivers/exoscale/].

Change the machine-type according to your needs / budget.

You can then test the nodes instances by connecting to it via ssh with:

    $ docker-machine ssh swarm-node-1

Or, from the swarm master, list the machine registered on consul:
    
    $ eval $(docker-machine env --swarm swarm-master)
    $ docker run swarm list consul://$(docker-machine ip consul):8500

Or check for the status of your cluster with:

    $ docker info

Which should return something similar to:

```
Containers: 5
Images: 4
Role: primary
Strategy: spread
Filters: health, port, dependency, affinity, constraint
Nodes: 2
 swarm-master: 185.19.XXX.XXX:2376
  └ Status: Healthy
  └ Containers: 3
  └ Reserved CPUs: 0 / 2
  └ Reserved Memory: 0 B / 2.053 GiB
  └ Labels: executiondriver=native-0.2, kernelversion=3.13.0-49-generic, operatingsystem=Ubuntu 14.04.2 LTS, provider=exoscale, storagedriver=aufs
 swarm-node-1: 185.19.XXX.XXX:2376
  └ Status: Healthy
  └ Containers: 2
  └ Reserved CPUs: 0 / 2
  └ Reserved Memory: 0 B / 2.053 GiB
  └ Labels: executiondriver=native-0.2, kernelversion=3.13.0-49-generic, operatingsystem=Ubuntu 14.04.2 LTS, provider=exoscale, storagedriver=aufs
CPUs: 4
Total Memory: 4.105 GiB
Name: 6ef8c1414e08
```

###Service discovery

We now have a setup where each node informations are stored in consul, so they can form a cluster. But once we run our containers in this cluster where can one of them get informations about other containers ? 
Since we already have a place suited to store host informations, why not using it to also store informations about the services our containers are running ?
To achieve this we are going to use the registrator image from the excellent gliderlabs repo. Note the usage of the constraint environnement variable when starting registrator; as we need one registrator running per node of the cluster we need to start this container on each of them. 

Be sure to administrate the cluster with:

    $ eval "$(docker-machine env --swarm swarm-master)"

for the swarm-master

    $ docker run -d \
        --name=registrator-master \
        --restart=always \
        --volume=/var/run/docker.sock:/tmp/docker.sock \
        -e constraint:node==swarm-master \
        gliderlabs/registrator:latest \
        -internal consul://$(docker-machine ip consul):8500

for each of the swarm nodes (modify the constraint accordingly to your nodes names):

    $ docker run -d \
        --name=registrator-node-1 \
        --restart=always \
        --volume=/var/run/docker.sock:/tmp/docker.sock \
        -e constraint:node==swarm-node-1 \
        gliderlabs/registrator:latest \
        -internal consul://$(docker-machine ip consul):8500

Check that your registrator container are running with `docker ps`, you should get something like:

```
CONTAINER ID        IMAGE                           COMMAND                  CREATED             STATUS              PORTS               NAMES
39be0b0965d6        gliderlabs/registrator:latest   "/bin/registrator -in"   10 minutes ago      Up 10 minutes                           swarm-node-1/registrator-node-1
6d271d4f037d        gliderlabs/registrator:latest   "/bin/registrator -in"   24 minutes ago      Up About a minute                       swarm-master/registrator-master
```

You can then query consul to get the list of registered services using the webui or with curl (assuming port 8500 is opened):

    $ curl $(docker-machine ip consul):8500/v1/catalog/services | jq .

Try the registration process by running a simple webserver that return the container id:

    $ docker run --name web1 -p 80 -d foostan/tinyweb
    $ curl $(docker-machine ip consul):8500/v1/catalog/service/tinyweb | jq .

It also possible to use a dns query to get information about registered service using (assuming you have udp/53 open toward consul):

    $ dig @$(docker-machine ip consul) tinyweb.service.consul
    $ dig @$(docker-machine ip consul) tinyweb.service.consul SRV

Remove your test container and verify it is deregistered properly:

    $ docker stop web1
    $ docker rm web1



