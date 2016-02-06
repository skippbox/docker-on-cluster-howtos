#Exoscale shell command list

This document is a compilation of useful commands to interact with your Exoscale account directly from the command line using cs.
Is it intended to help sysadmins save time when testing the API and/or writing provisionning scripts (for example with ansible or docker-machine).
The exhaustive documentation of the API calls you can use with your exoscale account is documented [here](https://community.exoscale.ch/api/compute/).

#Requirements

You will need to install on your machine the following tools:
- [cs](https://github.com/exoscale/cs)
- [jq](https://stedolan.github.io/jq/)

As per cs documentation, export the following values in your shell:

    CLOUDSTACK_ENDPOINT="https://api.exoscale.ch/compute"
    CLOUDSTACK_KEY="your api key"
    CLOUDSTACK_SECRET_KEY="your secret key"
    EXOSCALE_ACCOUNT_EMAIL="your@email.net"

Is it also possible to put those value in a .cloudstack.ini in your current folder. Refer to the documentation more informations.

##List your instances

List all your VMs:

    $ cs listVirtualMachines | jq

List only the running ones:

    $ cs listVirtualMachines state=Running | jq

Or the stopped ones:

    $ cs listVirtualMachines state=Stopped | jq

##List available templates

This list the different OS and disk size templates available to use with your vm:

    $ cs listTemplates templatefilter=featured

List only the template names:

    $ cs listTemplates templatefilter=featured | jq '.template[].displaytext'

Add the template id in the output:

    $ cs listTemplates templatefilter=featured | jq '{name:.template[].displaytext, id:.template[].id}'

Search for a template id using its displaytext:

    $ cs listTemplates templatefilter=featured | jq '.template[] | select(.displaytext=="Linux Ubuntu 15.04 64-bit 10G Disk (2015-04-22-c2595b)")'

Search for all templates based on CoreOS:

    $ cs listTemplates templatefilter=featured | jq '.template[] | select(.displaytext | contains("CoreOS"))'

##List available service offering

This list the different cpu and memory templates available to use with your vm:

    $ cs listServiceOfferings | jq '.serviceoffering[]'

##Create a security group

    $ cs createSecurityGroup name="my-security-group-1"

##Add rules in security group

Add a rule from one security group to another for a specific port / proto:

    $ cs authorizeSecurityGroupIngress protocol=TCP startPort=80 endPort=80 securityGroupName=consul usersecuritygrouplist[0].account=$EXOSCALE_ACCOUNT_EMAIL usersecuritygrouplist[0].group=my-security-group-1

Add a rule from one cidr to a security for a specific port / proto:

    $ cs authorizeSecurityGroupIngress protocol=TCP startPort=80 endPort=80 securityGroupName=my-security-group-1 cidrList=<your ip address/32>

##Create vm

This will create a vm using the OS flavor and disk size defined in the specified templateid and the cpu and memory defined in the specified serviceofferingid:

    $ cs deployVirtualMachine templateid="cdefccdb-996d-41c4-9ffc-7e493ba24957" zoneid="1128bd56-b4d9-4ac6-a7b9-c715b187ce11" serviceofferingid="21624abb-764e-4def-81d7-9fc54b5957fb" name="my new vm"

You can also specify a list of security groups you would like to use for this vm by appending: `securitygroupnames="my-security-group-1, my-security-group-2"` to this command.


