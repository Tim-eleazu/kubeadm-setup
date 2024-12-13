# This guide provides all the commands required to set up a Kubernetes cluster using `kubeadm`. Copy and paste the following commands to complete the setup


### On the Master Node

```
ip addr
```

# Use IP to initialize the master node
```
sudo kubeadm init --apiserver-advertise-address=<MASTER_NODE_IP> --pod-network-cidr=10.244.0.0/16 --upload-certs 
```
###   NOTE: pod-network-cidr is from the flannel.yaml file


```yaml
net-conf.json: |
  {
    "Network": "10.244.0.0/16",
    "EnableNFTables": false,
    "Backend": {
      "Type": "vxlan"
    }
  }
```

Get token and run on worker noes to join them to the cluster

Create a Shell Script on the masternode to setup network. I called my script bootstrap.sh. 




# Kubernetes Cluster Setup with Kubeadm
```bash
# Step 1: Get the Master Node's IP Address
ip addr

# Step 2: Initialize the Master Node (Replace <MASTER_NODE_IP> with the actual IP address)
sudo kubeadm init --apiserver-advertise-address=<MASTER_NODE_IP> --pod-network-cidr=10.244.0.0/16 --upload-certs


# Step 3 Configure the Kubernetes Network on the Master Node

Create and run a script to set up the Kubernetes network. Use the following commands:

```bash
cat <<EOF > bootstrap.sh
#!/bin/bash

# Set up kubeconfig
echo "Setting up kubeconfig for the current user..."
mkdir -p \$HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf \$HOME/.kube/config
sudo chown \$(id -u):\$(id -g) \$HOME/.kube/config
echo "Kubeconfig setup complete."

# Apply Flannel CNI
echo "Applying Flannel CNI..."
wget https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
echo "Flannel CNI applied successfully."
EOF

chmod +x bootstrap.sh
./bootstrap.sh
```