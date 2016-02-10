#!/bin/sh

# Deploy the overlord of our swarm, the node to host our consul KV store

# Assuming you have exported the following values:

# export EXOSCALE_ACCOUNT_EMAIL=<your exoscale mail>
# export CLOUDSTACK_KEY=<your exoscale api key>
# export CLOUDSTACK_SECRET_KEY=<your exoscale api secret key>
# export CLOUDSTACK_ENDPOINT=https://api.exoscale.ch/compute

docker-machine create --driver exoscale \
        --exoscale-api-key $CLOUDSTACK_KEY \
        --exoscale-api-secret-key $CLOUDSTACK_SECRET_KEY \
        --exoscale-instance-profile tiny \
        --exoscale-disk-size 10 \
        --exoscale-security-group consul \
        overlord

# Let's run consul
docker $(docker-machine config overlord) run --name consul \
    --restart=always  \
    -p 8500:8500  \
    -h consul \
    -d progrium/consul -server -bootstrap -ui-dir /ui

docker-machine scp -r ../apps/elk/conf-files/ $(docker-machine config overlord):
docker-machine scp -r ../apps/prometheus/conf-files/ $(docker-machine config overlord):

# docker $(docker-machine config overlord) run --name consul \
#     --restart=always  \
#     -p 8400:8400  \
#     -p 8500:8500  \
#     -p 53:53/udp  \
#     -h consul \
#     -d progrium/consul -server -bootstrap -ui-dir /ui