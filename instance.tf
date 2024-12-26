resource "aws_instance" "ap-project-01-server" {
  ami                    = var.ami
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.ap-project-01-sg.id]
  subnet_id              = aws_subnet.ap-project-01-subnet.id
  key_name               = aws_key_pair.generated.key_name
  count                  = 2

  depends_on = [aws_instance.Master-ap-project-01-server]

  user_data = <<-EOF
  #!/bin/bash
  set -e  # Exit on any error
  exec > /var/log/user-data.log 2>&1  # Log output for debugging

  echo "Starting worker node provisioning" > /tmp/user-data-debug.log

  # Set unique hostname
  echo "worker-node-$(hostname)" > /etc/hostname
  hostnamectl set-hostname worker-node-$(hostname)
  echo "Hostname set" >> /tmp/user-data-debug.log

  # Install Kubernetes components
  apt-get update && \
  apt-get install -y apt-transport-https ca-certificates curl gpg && \
  echo "Kubernetes components installed" >> /tmp/user-data-debug.log

  mkdir -p -m 700 /etc/apt/keyrings
  curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | \
    gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /" | \
    tee /etc/apt/sources.list.d/kubernetes.list
  apt-get update && \
  apt-get install -y kubelet kubeadm kubectl && \
  apt-mark hold kubelet kubeadm kubectl && \
  systemctl enable --now kubelet
  echo "Kubernetes components configured" >> /tmp/user-data-debug.log

  # Install the container runtime
  apt update && apt install -y containerd && \
  mkdir -p /etc/containerd && \
  containerd config default | sed 's/SystemdCgroup = false/SystemdCgroup = true/' > /etc/containerd/config.toml && \
  systemctl restart containerd
  echo "Container runtime installed" >> /tmp/user-data-debug.log

  # Enable IP forwarding
  sed -i '/^#*net.ipv4.ip_forward/c\net.ipv4.ip_forward = 1' /etc/sysctl.conf
  sysctl -p
  echo "IP forwarding enabled" >> /tmp/user-data-debug.log

  # Enable and load br_netfilter module
  echo 'br_netfilter' > /etc/modules-load.d/br_netfilter.conf
  modprobe br_netfilter
  echo "br_netfilter module loaded" >> /tmp/user-data-debug.log

  # Configure sysctl for bridged traffic
  echo "net.bridge.bridge-nf-call-ip6tables = 1" >> /etc/sysctl.conf
  echo "net.bridge.bridge-nf-call-iptables = 1" >> /etc/sysctl.conf
  sysctl -p
  echo "Sysctl configured for bridged traffic" >> /tmp/user-data-debug.log

  # Copy join command from master node
  MASTER_NODE_IP=${aws_instance.Master-ap-project-01-server.public_ip}
  scp -o StrictHostKeyChecking=no -i /home/ubuntu/.ssh/id_rsa ubuntu@$MASTER_NODE_IP:/tmp/kubeadm_join_command.sh /home/ubuntu/kubeadm_join_command.sh
  echo "Join command copied from master" >> /tmp/user-data-debug.log

  # Join the Kubernetes cluster
  chmod +x /tmp/kubeadm_join_command.sh
  /bin/bash /tmp/kubeadm_join_command.sh
  echo "Worker node joined the cluster" >> /tmp/user-data-debug.log
EOF


  tags = {
    Name = "${local.project_name}-worker-${count.index}"
  }
}



# # Introduce a delay after worker nodes are created
# resource "time_sleep" "wait_for_worker_nodes" {
#   depends_on = [
#     aws_instance.ap-project-01-server,        # Ensure the worker nodes are created
#     aws_instance.Master-ap-project-01-server, # Ensure the master node is ready
#     aws_key_pair.generated                    # Ensure the key pair is created
#   ]

#   create_duration = "2m" # Wait for 2 minutes
# }

# # Null resource for Node-01
# resource "null_resource" "copy_join_command_node_01" {
#   provisioner "remote-exec" {
#     connection {
#       type        = "ssh"
#       user        = "ubuntu"
#       host        = aws_instance.ap-project-01-server[0].public_ip
#       private_key = file(var.private_key_path)
#     }

#     inline = [
#       "scp -i kubeadm-project.pem -o StrictHostKeyChecking=no /tmp/kubeadm_join_command.sh ubuntu@${aws_instance.ap-project-01-server[0].public_ip}:/tmp/kubeadm_join_command.sh"
#     ]
#   }

#   depends_on = [time_sleep.wait_for_worker_nodes]
# }

# # Null resource for Node-02
# resource "null_resource" "copy_join_command_node_02" {
#   provisioner "remote-exec" {
#     connection {
#       type        = "ssh"
#       user        = "ubuntu"
#       host        = aws_instance.ap-project-01-server[1].public_ip
#       private_key = file(local.private_key_path)
#     }

#     inline = [
#       "scp -i kubeadm-project.pem -o StrictHostKeyChecking=no /tmp/kubeadm_join_command.sh ubuntu@${aws_instance.ap-project-01-server[1].public_ip}:/tmp/kubeadm_join_command.sh"
#     ]
#   }

#   depends_on = [time_sleep.wait_for_worker_nodes]
# }