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
    $ export CLOUDSTACK_SECRET=<your exoscale api secret key>
    $ export CLOUDSTACK_ENDPOINT=https://api.exoscale.ch/compute

##Setting up the Swarm !

###Creating a discovery service on a machine out of the cluster

Docker engines need a Key-value store to store informations. This is used by the swarm master to gather informations about the nodes joining the managed cluster. We are consul for this purpose, but alternatives exists, like etcd or zookeeper.

    $ docker-machine create --driver exoscale \
        --exoscale-api-key $CLOUDSTACK_KEY \
        --exoscale-api-secret-key $CLOUDSTACK_SECRET \
        --exoscale-instance-profile tiny \
        --exoscale-disk-size 10 \
        --exoscale-security-group consul \
        consul-master

Connect to this machine:

    $ eval $(docker-machine env consul-master)

Start a consul master node with:

    $ docker run --name consul-master \
    --restart=always  \
    -p 8400:8400  \
    -p 8500:8500  \
    -p 53:8600/udp  \
    -d gliderlabs/consul-server -server -bootstrap -ui-dir /ui

Finally create the swarm security group and add a firewall rule to allow our swarm nodes (which will be created in the swarm security group) to communicate with the consul server on the port tcp/8500 and udp/53.
    
    $ cs authorizeSecurityGroupIngress protocol=TCP startPort=8500 endPort=8500 securityGroupName=consul usersecuritygrouplist[0].account=$EXOSCALE_ACCOUNT_EMAIL usersecuritygrouplist[0].group=swarm

Of course you could also authorize your public ip address to access the consul web ui with something like:

    $ cs authorizeSecurityGroupIngress protocol=TCP startPort=8500 endPort=8500 securityGroupName=consul cidrList=<your ip address/32>

Or if you rather use dns queries:

    $ cs authorizeSecurityGroupIngress protocol=UDO startPort=53 endPort=53 securityGroupName=consul cidrList=<your ip address/32>

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
        --swarm-discovery="consul://$(docker-machine ip consul-master):8500" \
        --engine-opt="cluster-store=consul://$(docker-machine ip consul-master):8500" \
        --engine-opt="cluster-advertise=eth0:2376" \
        swarm-master

To connect to the master use:
    
    $ docker-machine ssh swarm-master

And enter our env (note the --swarm`):

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
        --swarm-discovery="consul://$(docker-machine ip consul-master):8500" \
        --engine-opt="cluster-store=consul://$(docker-machine ip consul-master):8500" \
        --engine-opt="cluster-advertise=eth0:2376" \
        swarm-node-1

Of course you can create as many nodes as needed.

More driver options are available: [https://docs.docker.com/machine/drivers/exoscale/].

Change the machine-type according to your needs / budget.

You can then test the nodes instances by connection to them with:

    $ docker-machine ssh swarm-node-1

Or from the swarm master list the machine registered on consul:

    $ docker run swarm list consul://$(docker-machine ip consul-master):8500

###Service discovery

We now have a setup where each node informations are stored in consul, so they can form a cluster. But once we run our containers in this cluster where can they get informations about other containers ? 
Since we already have a good place suited to store host informations, why not using it to also store containers informations ?
To achieve this we are going to use the registrator image from the excellent gliderlabs repo. Note the usage of the constraint environnement variable when starting registrator; as we need one registrator running per node of the cluster we need to start this container on each of them using constraint. 

for the swarm-master

    $ docker run -d \
        --name=registrator \
        --restart=always \
        --volume=/var/run/docker.sock:/tmp/docker.sock \
        -e constraint:node==swarm-master \
        gliderlabs/registrator:latest \
        -internal consul://$(docker-machine ip consul-master):8500

for each of the swarm node:

    $ docker run -d \
        --name=registrator \
        --restart=always \
        --volume=/var/run/docker.sock:/tmp/docker.sock \
        -e constraint:node==swarm-node-1 \
        gliderlabs/registrator:latest \
        -internal consul://$(docker-machine ip consul-master):8500

You can then query consul to get the list of registered services using the webui or with curl (assuming port 8500 is opened):

    $ curl $(docker-machine ip consul-master):8500/v1/catalog/services

Try the registration process by running a simple webserver that return the container id:

    $ docker run --name web1 -p 80 -d foostan/tinyweb

It also possible to use a dns query



