resource "aws_instance" "ap-project-01-server" {
  ami                    = var.ami
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.ap-project-01-sg.id]
  subnet_id              = aws_subnet.ap-project-01-subnet.id
  key_name               = aws_key_pair.generated.key_name
  count                  = 3

  user_data = <<-EOF
    #!/bin/bash
    exec > /var/log/user-data.log 2>&1

    # Set unique hostname
    echo "node-$(hostname)" > /etc/hostname
    hostnamectl set-hostname node-$(hostname)

    # Install Kubernetes components
    sudo apt-get update && \
    sudo apt-get install -y apt-transport-https ca-certificates curl gpg && \
    sudo mkdir -p -m 755 /etc/apt/keyrings && \
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg && \
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list && \
    sudo apt-get update && \
    sudo apt-get install -y kubelet kubeadm kubectl && \
    sudo apt-mark hold kubelet kubeadm kubectl && \
    sudo systemctl enable --now kubelet

    # Install the container runtime
    sudo apt update && sudo apt install -y containerd
    sudo mkdir -p /etc/containerd
    containerd config default | sed 's/SystemdCgroup = false/SystemdCgroup = true/' | sudo tee /etc/containerd/config.toml
    sudo systemctl restart containerd

    # Enable IP forwarding
    sudo sed -i '/^#*net.ipv4.ip_forward/c\net.ipv4.ip_forward = 1' /etc/sysctl.conf
    sudo sysctl -p

    # Enable and load br_netfilter module
    echo 'br_netfilter' | sudo tee /etc/modules-load.d/br_netfilter.conf
    sudo modprobe br_netfilter

    # Configure sysctl for bridged traffic
    echo "net.bridge.bridge-nf-call-ip6tables = 1" | sudo tee -a /etc/sysctl.conf
    echo "net.bridge.bridge-nf-call-iptables = 1" | sudo tee -a /etc/sysctl.conf
    echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf
    sudo sysctl -p

    # Restart kubelet to apply changes
    sudo systemctl restart kubelet
  EOF

  tags = {
    Name = "${local.project_name}-instance-${count.index}"
  }
}