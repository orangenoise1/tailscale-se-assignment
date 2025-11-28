terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  # Overall VPC CIDR that we advertise via the subnet router
  vpc_cidr = "10.0.1.0/24"

  # Carve out two small subnets inside the VPC
  public_subnet_cidr  = "10.0.1.0/28"
  private_subnet_cidr = "10.0.1.16/28"
}

# Networking

resource "aws_vpc" "vpc" {
  cidr_block           = local.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# Public subnet (for NAT gateway)
resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = local.public_subnet_cidr

  tags = {
    Name = "${var.project_name}-subnet-public"
  }
}

# Private subnet (for EC2 instances)
resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = local.private_subnet_cidr

  tags = {
    Name = "${var.project_name}-subnet-private"
  }
}

# Route table for public subnet (Internet via IGW)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.project_name}-rt-public"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# NAT gateway in public subnet (for private subnet outbound access)
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-eip-nat"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "${var.project_name}-nat-gw"
  }
}

# Route table for private subnet (Internet via NAT)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "${var.project_name}-rt-private"
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# Security group: ICMP within VPC + all egress
resource "aws_security_group" "nodes" {
  name        = "${var.project_name}-nodes-sg"
  description = "Security group for Tailscale lab nodes"
  vpc_id      = aws_vpc.vpc.id

  # Allow ICMP (ping) from within the VPC so we can demo routing
  ingress {
    description = "Allow ICMP within VPC for demo"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [local.vpc_cidr]
  }

  # All outbound allowed (needed for Tailscale to reach the control plane)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-nodes-sg"
  }
}

# AMI lookup

data "aws_ami" "amazon_linux" {
  most_recent = true

  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# Subnet router instance

resource "aws_instance" "subnet_router" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.nodes.id]

  associate_public_ip_address = false
  source_dest_check           = false # required so it can act as a router

  tags = {
    Name = "${var.project_name}-subnet-router"
  }

  user_data = <<-EOF
#!/bin/bash

dnf -y update

# Enable IP forwarding so this instance can route traffic for the VPC
cat <<SYSCTL >/etc/sysctl.d/99-tailscale.conf
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
SYSCTL
sysctl -p /etc/sysctl.d/99-tailscale.conf || true

# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh
systemctl enable --now tailscaled

# Join tailnet and advertise the VPC as a subnet route
tailscale up \
  --auth-key=${var.subnet_router_authkey} \
  --hostname="${var.project_name}-subnet-router" \
  --advertise-routes=${local.vpc_cidr} \
  --accept-dns=true
EOF
}

# SSH node instance

resource "aws_instance" "ssh_node" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.nodes.id]

  associate_public_ip_address = false

  tags = {
    Name = "${var.project_name}-ssh-node"
  }

  user_data = <<-EOF
#!/bin/bash

dnf -y update

curl -fsSL https://tailscale.com/install.sh | sh
systemctl enable --now tailscaled

# Join tailnet with Tailscale SSH enabled
tailscale up \
  --auth-key=${var.ssh_node_authkey} \
  --hostname="${var.project_name}-ssh-node" \
  --ssh=true \
  --accept-dns=true
EOF
}