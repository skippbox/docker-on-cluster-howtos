#kubernetes cheatsheet

##Local port forwarding from the master

    $ ssh -nNT -L 8080:127.0.0.1:8080 -i ~/.ssh/id_rsa_k8s core@<master-node-ip> &

##API

http://master-node-ip:8080/

##kubectl

By default kubectl uses http://127.0.0.1:8080 (Create a ssh tunnel if your k8s does not run locally)

View the current config:

    $ kubectl config view

Unset current config:

    $ kubectl config unset current-context

check cluster status

    $ kubectl get nodes