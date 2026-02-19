resource "aws_instance" "Master-ap-project-01-server" {
  ami                    = var.ami
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.ap-project-01-sg.id]
  subnet_id              = aws_subnet.ap-project-01-subnet.id
  key_name               = aws_key_pair.generated.key_name

  user_data = <<-EOF
    #!/bin/bash
    # Redirect all stdout and stderr to a log file for debugging purposes
    exec > /var/log/user-data.log 2>&1

    # Set unique hostname by prefixing "master-node-" to the current hostname
    # Write hostname to /etc/hostname file for persistence across reboots
    echo "master-node-$(hostname)" > /etc/hostname
    # Apply the new hostname immediately without requiring a reboot
    hostnamectl set-hostname master-node-$(hostname)

    # Update package index and install prerequisite packages for adding Kubernetes apt repository
    apt-get update && \
    apt-get install -y apt-transport-https ca-certificates curl gpg && \
    # Create keyrings directory with proper permissions to store GPG keys
    mkdir -p -m 755 /etc/apt/keyrings && \
    # Download and convert Kubernetes GPG key to binary format for apt verification
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg && \
    # Add the official Kubernetes apt repository to sources list
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list && \
    # Update package index again to include Kubernetes packages
    apt-get update && \
    # Install kubelet (node agent), kubeadm (cluster bootstrapper), and kubectl (CLI tool)
    apt-get install -y kubelet kubeadm kubectl && \
    # Prevent automatic updates to Kubernetes packages to maintain cluster stability
    apt-mark hold kubelet kubeadm kubectl && \
    # Enable kubelet service to start on boot and start it immediately
    systemctl enable --now kubelet

    # Update package index and install containerd as the container runtime
    apt update && apt install -y containerd
    # Create containerd configuration directory
    mkdir -p /etc/containerd
    # Generate default containerd config and enable systemd cgroup driver for Kubernetes compatibility
    containerd config default | sed 's/SystemdCgroup = false/SystemdCgroup = true/' | tee /etc/containerd/config.toml
    # Restart containerd to apply the new configuration
    systemctl restart containerd

    # Enable IPv4 packet forwarding in sysctl.conf (required for pod networking)
    sed -i '/^#*net.ipv4.ip_forward/c\net.ipv4.ip_forward = 1' /etc/sysctl.conf
    # Apply sysctl settings immediately without reboot
    sysctl -p

    # Load br_netfilter kernel module on boot (required for iptables to see bridged traffic)
    echo 'br_netfilter' | tee /etc/modules-load.d/br_netfilter.conf
    # Load the br_netfilter module immediately
    modprobe br_netfilter

    # Enable iptables to process IPv6 bridged traffic
    echo "net.bridge.bridge-nf-call-ip6tables = 1" | tee -a /etc/sysctl.conf
    # Enable iptables to process IPv4 bridged traffic
    echo "net.bridge.bridge-nf-call-iptables = 1" | tee -a /etc/sysctl.conf
    # Ensure IP forwarding is enabled (redundant but ensures it's set)
    echo "net.ipv4.ip_forward = 1" | tee -a /etc/sysctl.conf
    # Apply the new sysctl settings
    sysctl -p

    # Download cfssl (CloudFlare's SSL toolkit) for generating TLS certificates
    wget -q --show-progress --https-only --timestamping \
      https://storage.googleapis.com/kubernetes-the-hard-way/cfssl/1.4.1/linux/cfssl \
      https://storage.googleapis.com/kubernetes-the-hard-way/cfssl/1.4.1/linux/cfssljson

    # Make the cfssl binaries executable
    chmod +x cfssl cfssljson
    # Move cfssl binaries to system PATH for global access
    sudo mv cfssl cfssljson /usr/local/bin/

    # Get the primary IP address of this node for API server advertisement
    MASTER_NODE_IP=$(hostname -I | awk '{print $1}')
    # Initialize the Kubernetes control plane with specified API server address and pod CIDR
    kubeadm init --apiserver-advertise-address=$MASTER_NODE_IP --pod-network-cidr=10.244.0.0/16 --upload-certs

    # Create .kube directory for root user to store kubeconfig
    mkdir -p /root/.kube
    # Copy the admin kubeconfig to root's home directory
    cp -i /etc/kubernetes/admin.conf /root/.kube/config
    # Set proper ownership for the kubeconfig file
    chown root:root /root/.kube/config

    # Check if ubuntu user exists before configuring kubectl for them
    if id "ubuntu" &>/dev/null; then
    # Create .kube directory for ubuntu user
    mkdir -p /home/ubuntu/.kube
    # Copy admin kubeconfig to ubuntu user's home directory
    cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
    # Set proper ownership for ubuntu user's kubeconfig
    chown ubuntu:ubuntu /home/ubuntu/.kube/config
    fi

    # Change to ubuntu's home directory for downloading network plugin
    cd /home/ubuntu/
    # Download Calico CNI manifest for pod networking
    sudo wget https://docs.projectcalico.org/manifests/calico.yaml
    # Apply Calico network plugin to enable pod-to-pod communication
    sudo kubectl apply -f calico.yaml --validate=false

    # Generate a new bootstrap token and save the join command for worker nodes
    kubeadm token create --print-join-command > /tmp/kubeadm_join_command.sh

    # Log success message
    echo "Calico CNI applied successfully."

    # Enable kubectl bash completion for root user (tab completion for commands)
    echo "source <(kubectl completion bash)" >> /root/.bashrc
    # Create shorthand alias 'k' for kubectl command
    echo "alias k=kubectl" >> /root/.bashrc
    # Enable bash completion for the 'k' alias
    echo "complete -o default -F __start_kubectl k" >> /root/.bashrc

    # Apply same kubectl shortcuts for ubuntu user if they exist
    if id "ubuntu" &>/dev/null; then
        echo "source <(kubectl completion bash)" >> /home/ubuntu/.bashrc
        echo "alias k=kubectl" >> /home/ubuntu/.bashrc
        echo "complete -o default -F __start_kubectl k" >> /home/ubuntu/.bashrc
    fi
  EOF

  tags = {
    Name = "${local.project_name}-master-instance"
  }
}


resource "null_resource" "copy_key_to_master" {
  provisioner "file" {
    source      = "${local.project_name}.pem"
    destination = "/home/ubuntu/.ssh/id_rsa"

    connection {
      type        = "ssh"
      host        = aws_instance.Master-ap-project-01-server.public_ip
      user        = "ubuntu"
      private_key = file("${local.project_name}.pem")
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv /home/ubuntu/.ssh/id_rsa /root/.ssh/id_rsa",
      "sudo chmod 600 /root/.ssh/id_rsa",
      "sudo chown root:root /root/.ssh/id_rsa"
    ]

    connection {
      type        = "ssh"
      host        = aws_instance.Master-ap-project-01-server.public_ip
      user        = "ubuntu"
      private_key = file("${local.project_name}.pem")
    }
  }

  depends_on = [aws_instance.Master-ap-project-01-server]
}