###Consul cluster

    $ docker run --restart=always -d --name consul -v /opt/consul:/opt/consul -p 8300:8300 -p 8301:8301 -p 8301:8301/udp -p 8302:8302 -p 8302:8302/udp -p 8400:8400 -p 8500:8500 -p 8600:53/udp gliderlabs/consul agent -server -data-dir=/opt/consul/data -config-dir=/opt/consul/config -advertise=10.246.246.174 -node=dev-do1 -bootstrap-expect=3

Other nodes can join the cluster with `-join=dev-do1`

###Copy config files on nodes:

    $ docker-machine scp -r conf-files/ swarm-master: && docker-machine scp -r conf-files/ swarm-node-1:

###Networking

Using the new --x-networking argument of the docker-compose command we can now create an overlay network, that will be used by all the container described in our compose file:

    $ docker-compose --x-networking up -d
    Creating network "swarm" with driver "None"

For overlay network to function you need to open between all your swarn node

- udp 4789    Data plane (VXLAN)
- tcp/udp 7946    Control plane

If you get the following error

    ERROR: Cannot start container 7a725c309c321b2c40f0e4f56460b835c2df0746b7edc369a4daa62ca8511f61: subnet sandbox join failed for "10.0.0.0/24": vxlan interface creation failed for subnet "10.0.0.0/24": failed in prefunc: failed to set namespace on link "vxlan2b78a06": invalid argument

Then you need to update your node kernel to > 3.15

    $ docker-machine ssh swarm-master "sudo apt-get update && sudo apt-get install -y linux-image-3.16.0-53-generic linux-image-extra-3.16.0-53-generic && sudo reboot"
    $ docker-machine ssh swarm-node-1 "sudo apt-get update && sudo apt-get install -y linux-image-3.16.0-53-generic linux-image-extra-3.16.0-53-generic && sudo reboot"
    ...

###Load balancing with haproxy

https://hub.docker.com/r/qapps/failover/

##Scaling

    docker-compose scale=3 <app name>

##Promotheus

Promotheus pull information about containers from cadvisor instances running on each nodes.
Let's run a cadvisor on all our cluster nodes.
On the master:

    $ docker run -d \
      -p 8888:8080 \
      --name=cadvisor-master \
      --restart=always \
      --volume=/var/run/docker.sock:/tmp/docker.sock \
      --volume=/:/rootfs:ro \
      --volume=/var/run:/var/run:rw \
      --volume=/sys:/sys:ro \
      --volume=/var/lib/docker/:/var/lib/docker:ro \
      -e constraint:node==swarm-master \
      google/cadvisor:latest

On our first node:

    $ docker run -d \
      -p 8888:8080 \
      --name=cadvisor-node-1 \
      --restart=always \
      --volume=/var/run/docker.sock:/tmp/docker.sock \
      --volume=/:/rootfs:ro \
      --volume=/var/run:/var/run:rw \
      --volume=/sys:/sys:ro \
      --volume=/var/lib/docker/:/var/lib/docker:ro \
      -e constraint:node==swarm-node-1 \
      google/cadvisor:latest
