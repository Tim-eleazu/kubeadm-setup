# This guide provides all the commands required to set up a Kubernetes cluster using `kubeadm`. Copy and paste the following commands to complete the setup

### Get token from master node and run on worker noes to join them to the cluster

### Configure the Kubernetes Network on the Master Node

## Copy the token and run on the Worker nodes

### To copy token 
```
cat /tmp/kubeadm_join_command.sh
```
### Use token on worker nodes
```
sudo < token >
```