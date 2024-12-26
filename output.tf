output "Master" {
  value = aws_instance.Master-ap-project-01-server.public_ip
}

output "Node-01" {
  value = aws_instance.ap-project-01-server[0].public_ip
}

output "Node-02" {
  value = aws_instance.ap-project-01-server[1].public_ip
}

# Optional
# output "Node-03" {
#   value = aws_instance.ap-project-01-server[2].public_ip
# }