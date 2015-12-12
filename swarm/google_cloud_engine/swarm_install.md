In this introduction to swarm we will use:

- Make sure you have Docker 1.9, Machine 0.5, and Compose 1.5 installed.

##Setting up google cloud

We will use gcloud, a tool by google to manage instances in our google cloud engine account. Let's install it and login with:

    $ curl -sSL https://sdk.cloud.google.com | bash
    $ gcloud auth login

Select a project > create project. From now on, we will use this project ID

    $ export PROJECT_ID=<your-project-id>

##Setting up the Swaaaaaaaarm

####Creating a discovery service on a machine out of the cluster

    $ docker-machine create --driver google \
        --google-project  \
        --google-zone europe-west1-b \
        --google-machine-type f1-micro \
        consul-master

Connect to it:

    $ eval $(docker-machine env consul-master)

Start consul with:

    $ docker run --name consul-master --restart=always -p 8500:8500 -d progrium/consul -server -bootstrap -ui-dir /ui

Finally add a firewall rule to allow our swarm node to communicate with the consul server on the port 8500:
    
    $ gcloud compute --project $PROJECT_ID firewall-rules create "consul" --allow tcp:8500  --network "default" --source-tags "docker-machine"

####Creating the swarm master

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

To connect to the master use:
    
    $ docker-machine ssh swarm-master

And enter our env (note the --swarm`):

    $ eval $(docker-machine env --swarm swarm-master)

Here I got an issue, the machine swarm port were not opened correctly on the GCE firewall, this solved the issue (See [https://github.com/docker/machine/issues/1432]):

    gcloud compute firewall-rules create swarm-machines --allow tcp:3376 --source-ranges 0.0.0.0/0 --target-tags docker-machine --project $PROJECT_ID

After this I could use the `docker-machine env` command without issue.

####Creating a swarm node

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

You can then test the nodes instances by connection to them with:

    $ docker-machine ssh swarm-node-1

Or from the swarm master list the machine registered on consul:

    $ docker run swarm list consul://$(docker-machine ip consul-master):8500

Or check for the status of your cluster with:

    $ docker info

Which should return something similar to:

```
  docker info
Containers: 15
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
 swarm-node-2: XXX.XXX.XXX.XXX:2376
  └ Containers: 5
  └ Reserved CPUs: 0 / 1
  └ Reserved Memory: 0 B / 3.795 GiB
  └ Labels: executiondriver=native-0.2, kernelversion=3.19.0-28-generic, operatingsystem=Ubuntu 14.04.3 LTS, provider=google, storagedriver=aufs
CPUs: 3
Total Memory: 11.38 GiB
Name: 11ba8054e7aa
```

####Networking
This part assume you have a Compose describing the application you want to start.
The new --x-networking argument of the docker-compose command we can now create an overlay network, that will be used by all the containers described in our compose file:

    docker-compose --x-networking up -d 

####Scaling

It's now easy to scale an application describe in docker-compose.yml file with:

    docker-compose scale=3 <app name>
    docker-compose up --force-recreate -d


