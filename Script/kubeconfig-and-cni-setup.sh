#!/bin/bash

# Set up kubeconfig
echo "Setting up kubeconfig for the current user..."
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
echo "Kubeconfig setup complete."

# Apply Flannel CNI
echo "Applying Flannel CNI..."
wget https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
echo "Flannel CNI applied successfully."