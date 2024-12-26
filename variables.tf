locals {
  private_key_path = "./${var.project-name}.pem"
}
variable "project-name" {}
variable "region" {}
variable "az-zone" {}
variable "vpc_cidr_block" {}
variable "subnet_cidr_block" {}
variable "cidr_blocks" {}
variable "instance_type" {}
variable "ami" {}
variable "private_key_path" {
  description = "Path to the private key file used for SSH connections"
  type        = string
}