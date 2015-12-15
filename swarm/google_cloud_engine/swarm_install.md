#How to create a swarm cluster on GCE (Google cloud engine)

This document describes the necessary steps to create a swarm cluster on [Google cloud engine](cloud.google.com) cloud provider.
Make sure you have Docker 1.9, Machine 0.5, and Compose 1.5 installed.
See http://docs.docker.com to access the installation documentation of docker-machine for your platform.

##Setting up google cloud

We will use gcloud, a tool by google to manage instances in our google cloud engine account. Let's install it and login with:

    $ curl -sSL https://sdk.cloud.google.com | bash
    $ gcloud auth login

Select a project > create project. From now on, we will use this project ID

    $ export PROJECT_ID=<your-project-id>

##Setting up the Swarm !

###Creating a discovery service on a machine out of the cluster

Docker engines need a key-value store to store informations. This is used by the swarm master to gather informations about the nodes joining the managed cluster. Thanks to hashicorp we now have [consul](https://www.consul.io/) for this purpose, but alternatives exists, like etcd or zookeeper.

    $ docker-machine create --driver google \
        --google-project  \
        --google-zone europe-west1-b \
        --google-machine-type f1-micro \
        consul-master

Connect to it:

    $ eval $(docker-machine env consul-master)

Start a consul container with:

    $ docker run --name consul \
    --restart=always  \
    -p 8400:8400  \
    -p 8500:8500  \
    -p 53:53/udp  \
    -h consul \
    -d progrium/consul -server -bootstrap-expect 1 -ui-dir /ui

Finally add a firewall rule to allow our swarm node to communicate with the consul server on the port 8500:
    
    $ gcloud compute --project $PROJECT_ID firewall-rules create "consul" --allow tcp:8500  --network "default" --source-tags "docker-machine"

Administrate this instance using docker-machine with:

    $ eval $(docker-machine env consul)

###Creating the swarm master

We need instances on which to install swarm. Let's first create the master with:
    
    $ docker-machine create --driver google \
        --google-project $PROJECT_ID \
        --google-zone europe-west1-b \
        --google-machine-type n1-standard-1  \
        --swarm \
        --swarm-master \
        --swarm-discovery="consul://$(docker-machine ip consul-master):8500" \
        --engine-opt="cluster-store=consul://$(docker-machine ip consul-master):8500" \
        --engine-opt="cluster-advertise=eth0:2376" \
        swarm-master

To connect to the master via ssh use:
    
    $ docker-machine ssh swarm-master

Administrate the cluster using docker-machine with: (note the `--swarm`):

    $ eval $(docker-machine env --swarm swarm-master)

Here I got an issue, the machine swarm port were not opened correctly on the GCE firewall, this solved the issue (See https://github.com/docker/machine/issues/1432):

    $ gcloud compute firewall-rules create swarm-machines --allow tcp:3376 --source-ranges 0.0.0.0/0 --target-tags docker-machine --project $PROJECT_ID

###Creating a swarm node

    $ docker-machine create --driver google \
        --google-project $PROJECT_ID  \
        --google-zone europe-west1-b \
        --google-machine-type n1-standard-1 \
        --swarm \
        --swarm-discovery="consul://$(docker-machine ip consul-master):8500" \
        --engine-opt="cluster-store=consul://$(docker-machine ip consul-master):8500" \
        --engine-opt="cluster-advertise=eth0:2376" \
        swarm-node-1

Of course you can create as many nodes as needed.

More driver option are available: [https://docs.docker.com/machine/drivers/gce/].

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
Images: 10
Role: primary
Strategy: spread
Filters: health, port, dependency, affinity, constraint
Nodes: 3
 swarm-master: XXX.XXX.XXX.XXX:2376
  └ Containers: 6
  └ Reserved CPUs: 0 / 1
  └ Reserved Memory: 0 B / 3.795 GiB
  └ Labels: executiondriver=native-0.2, kernelversion=3.19.0-28-generic, operatingsystem=Ubuntu 14.04.3 LTS, provider=google, storagedriver=aufs
 swarm-node-1: XXX.XXX.XXX.XXX:2376
  └ Containers: 4
  └ Reserved CPUs: 0 / 1
  └ Reserved Memory: 0 B / 3.795 GiB
  └ Labels: executiondriver=native-0.2, kernelversion=3.19.0-28-generic, operatingsystem=Ubuntu 14.04.3 LTS, provider=google, storagedriver=aufs
CPUs: 3
Total Memory: 11.38 GiB
Name: 11ba8054e7aa
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

It also possible to use a dns query to get information about registered service using (assuming you have udp/53 open toward consul:

    $ dig @$(docker-machine ip consul) tinyweb.service.consul
    $ dig @$(docker-machine ip consul) tinyweb.service.consul SRV

Remove your test container and verify it is deregistered properly:

    $ docker stop web1
    $ docker rm web1






