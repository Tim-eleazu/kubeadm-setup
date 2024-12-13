resource "tls_private_key" "generated" {
  algorithm = "RSA"
}

resource "local_file" "private_key_pem" {
  content  = tls_private_key.generated.private_key_pem
  filename = "${local.project_name}.pem"
}

resource "aws_key_pair" "generated" {
  key_name   = local.project_name
  public_key = tls_private_key.generated.public_key_openssh
}