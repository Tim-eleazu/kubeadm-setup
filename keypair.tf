# Generate a private key
resource "tls_private_key" "generated" {
  algorithm = "RSA"
}


resource "local_file" "private_key_pem" {
  content  = tls_private_key.generated.private_key_pem
  filename = "${local.project_name}.pem"

  provisioner "local-exec" {
    command = "chmod 600 ${local.project_name}.pem"
  }
}

resource "aws_key_pair" "generated" {
  key_name   = local.project_name
  public_key = tls_private_key.generated.public_key_openssh

  provisioner "local-exec" {
    command = <<-EOT
      echo '${tls_private_key.generated.private_key_pem}' > ./${local.project_name}.pem
      chmod 600 ./${local.project_name}.pem
    EOT
  }
}
