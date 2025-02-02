locals {
  project_name = var.project-name
}

# AWS VPC
resource "aws_vpc" "ap-project-01" {
  cidr_block = var.vpc_cidr_block

  tags = {
    Name = "${local.project_name}-vpc"
  }
}

# SUBNET
resource "aws_subnet" "ap-project-01-subnet" {
  vpc_id                  = aws_vpc.ap-project-01.id
  cidr_block              = var.subnet_cidr_block
  availability_zone       = var.az-zone
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.project_name}-subnet"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "ap-project-01-gw" {
  vpc_id = aws_vpc.ap-project-01.id

  tags = {
    Name = "${local.project_name}-gateway"
  }
}

# ROUTE TABLE
resource "aws_route_table" "ap-project-01-rt" {
  vpc_id = aws_vpc.ap-project-01.id

  route {
    cidr_block = var.cidr_blocks
    gateway_id = aws_internet_gateway.ap-project-01-gw.id
  }

  tags = {
    Name = "${local.project_name}-rt"
  }
}

#ROUTE TABLE ASSOCIATION
resource "aws_route_table_association" "ap-project-01-rt-assoc" {
  route_table_id = aws_route_table.ap-project-01-rt.id
  subnet_id      = aws_subnet.ap-project-01-subnet.id
}

# SECURITY GROUP
resource "aws_security_group" "ap-project-01-sg" {
  name   = "${local.project_name}-sg"
  vpc_id = aws_vpc.ap-project-01.id

  ingress = concat(
    [
      for port in [80, 8080, 8089, 22, 6443, 10250, 10251, 10252, 30007] : {
        description      = "Allow communication on port ${port}"
        from_port        = port
        to_port          = port
        protocol         = "tcp"
        cidr_blocks      = [var.cidr_blocks] 
        ipv6_cidr_blocks = ["::/0"]
        self             = false
        prefix_list_ids  = []
        security_groups  = []
      }
    ],
    [
      {
        description      = "Allow etcd server client API communication"
        from_port        = 2379
        to_port          = 2380
        protocol         = "tcp"
        cidr_blocks      = [var.cidr_blocks] # Replace with your VPC CIDR block
        ipv6_cidr_blocks = ["::/0"]
        self             = false
        prefix_list_ids  = []
        security_groups  = []
      },
      {
        description      = "Allow DNS resolution for CoreDNS"
        from_port        = 53
        to_port          = 53
        protocol         = "udp"
        cidr_blocks      = [var.cidr_blocks] # Replace with your VPC CIDR block
        ipv6_cidr_blocks = ["::/0"]
        self             = false
        prefix_list_ids  = []
        security_groups  = []
      },
      {
        description      = "Allow ICMP traffic for ping"
        from_port        = -1
        to_port          = -1
        protocol         = "icmp"
        cidr_blocks      = [var.cidr_blocks] # Replace with your VPC CIDR block
        ipv6_cidr_blocks = ["::/0"]
        self             = false
        prefix_list_ids  = []
        security_groups  = []
      },
      {
        description      = "Allow worker node communication"
        from_port        = 30000
        to_port          = 32767
        protocol         = "tcp"
        cidr_blocks      = [var.cidr_blocks] # Replace with your VPC CIDR block
        ipv6_cidr_blocks = ["::/0"]
        self             = false
        prefix_list_ids  = []
        security_groups  = []
      }
    ]
  )

  egress = [{
    description      = "Allow all outgoing traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = [var.cidr_blocks]
    ipv6_cidr_blocks = ["::/0"]
    self             = false
    prefix_list_ids  = []
    security_groups  = []
  }]
}