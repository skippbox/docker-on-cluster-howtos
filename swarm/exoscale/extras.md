###Consul cluster

    $ docker run --restart=always -d --name consul -v /opt/consul:/opt/consul -p 8300:8300 -p 8301:8301 -p 8301:8301/udp -p 8302:8302 -p 8302:8302/udp -p 8400:8400 -p 8500:8500 -p 8600:53/udp gliderlabs/consul agent -server -data-dir=/opt/consul/data -config-dir=/opt/consul/config -advertise=10.246.246.174 -node=dev-do1 -bootstrap-expect=3

other nodes with `-join=dev-do1

###Networking

Using the new --x-networking argument of the docker-compose command we can now create an overlay network, that will be used by all the container describe in our compose file:

    docker-compose --x-networking up -d 

For overlay network to function you need to open between all your swarn node

kernel > 3.15

    $ docker-machine ssh swarm-master "sudo apt-get update && sudo apt-get -y  install linux-image-3.16.0-53-generic install linux-image-extra-3.16.0-53-generic && sudo reboot"
    $ docker-machine ssh swarm-master "sudo apt-get update && sudo apt-get -y  install linux-image-3.16.0-53-generic install linux-image-extra-3.16.0-53-generic && sudo reboot"
    ...

reboot
    
    $ cs reboot ?

udp 4789    Data plane (VXLAN)
tcp/udp 7946    Control plane

###Load balancing with haproxy

consul-template
https://hub.docker.com/r/qapps/failover/

##Scaling

    docker-compose scale=3 <app name>
    docker-compose up --force-recreate -d