resource "aws_instance" "Master-ap-project-01-server" {
  ami                    = var.ami
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.ap-project-01-sg.id]
  subnet_id              = aws_subnet.ap-project-01-subnet.id
  key_name               = aws_key_pair.generated.key_name

  user_data = <<-EOF
    #!/bin/bash
    exec > /var/log/user-data.log 2>&1

    # Set unique hostname
    echo "master-node-$(hostname)" > /etc/hostname
    hostnamectl set-hostname master-node-$(hostname)

    # Install Kubernetes components
    apt-get update && \
    apt-get install -y apt-transport-https ca-certificates curl gpg && \
    mkdir -p -m 755 /etc/apt/keyrings && \
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg && \
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list && \
    apt-get update && \
    apt-get install -y kubelet kubeadm kubectl && \
    apt-mark hold kubelet kubeadm kubectl && \
    systemctl enable --now kubelet

    # Install the container runtime
    apt update && apt install -y containerd
    mkdir -p /etc/containerd
    containerd config default | sed 's/SystemdCgroup = false/SystemdCgroup = true/' | tee /etc/containerd/config.toml
    systemctl restart containerd

    # Enable IP forwarding
    sed -i '/^#*net.ipv4.ip_forward/c\net.ipv4.ip_forward = 1' /etc/sysctl.conf
    sysctl -p

    # Enable and load br_netfilter module
    echo 'br_netfilter' | tee /etc/modules-load.d/br_netfilter.conf
    modprobe br_netfilter

    # Configure sysctl for bridged traffic
    echo "net.bridge.bridge-nf-call-ip6tables = 1" | tee -a /etc/sysctl.conf
    echo "net.bridge.bridge-nf-call-iptables = 1" | tee -a /etc/sysctl.conf
    echo "net.ipv4.ip_forward = 1" | tee -a /etc/sysctl.conf
    sysctl -p

    # Install cfssl and cfssljson ---for Security
    wget -q --show-progress --https-only --timestamping \
      https://storage.googleapis.com/kubernetes-the-hard-way/cfssl/1.4.1/linux/cfssl \
      https://storage.googleapis.com/kubernetes-the-hard-way/cfssl/1.4.1/linux/cfssljson

    chmod +x cfssl cfssljson
    sudo mv cfssl cfssljson /usr/local/bin/

    # Initialize the Kubernetes Master Node
    MASTER_NODE_IP=$(hostname -I | awk '{print $1}')
    kubeadm init --apiserver-advertise-address=$MASTER_NODE_IP --pod-network-cidr=10.244.0.0/16 --upload-certs

    mkdir -p /root/.kube
    cp -i /etc/kubernetes/admin.conf /root/.kube/config
    chown root:root /root/.kube/config

    # Optional: Configure kubectl for the ubuntu user
    if id "ubuntu" &>/dev/null; then
    mkdir -p /home/ubuntu/.kube
    cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
    chown ubuntu:ubuntu /home/ubuntu/.kube/config
    fi

    # Apply Calico network plugin
    cd /home/ubuntu/
    sudo wget https://docs.projectcalico.org/manifests/calico.yaml
    sudo kubectl apply -f calico.yaml --validate=false

    # Save the join command to a file for workers to use
    kubeadm token create --print-join-command > /tmp/kubeadm_join_command.sh

    echo "Calico CNI applied successfully."

    # Kubeadm shortcut
    echo "source <(kubectl completion bash)" >> /root/.bashrc
    echo "alias k=kubectl" >> /root/.bashrc
    echo "complete -o default -F __start_kubectl k" >> /root/.bashrc

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