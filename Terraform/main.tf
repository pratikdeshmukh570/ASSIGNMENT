#Provider

provider "aws" {
  region = "ap-south-1"  
  access_key = "XXXXXXXXXXXXXXXXXXXXXXX"
  secret_key = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
}

#Create Vpc

resource "aws_vpc" "dollar_vpc" {
  cidr_block = "10.0.0.0/16"  
  tags = {
    Name = "dollar_vpc-vpc"
  }
}

#Creating Public Subnet

resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.dollar_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "dollar_vpc-public-subnet"
  }
}

#Create Private Subnet

resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.dollar_vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "ap-south-1a"
  tags = {
    Name = "dollar_vpc-private-subnet"
  }
}

resource "aws_eip" "nat_eip" {
  vpc = true
}

#Create internet gateway for VPC

resource "aws_internet_gateway" "nat_ig" {
  vpc_id = aws_vpc.dollar_vpc.id
}

#Route tables for public subnet

resource "aws_route_table" "public_route" {
  vpc_id = aws_vpc.dollar_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.nat_ig.id # Internet Gateway
  }
}

#Associate route table to public subnet

resource "aws_route_table_association" "public_route_association" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_route.id
}

#Route tables for private subnet

resource "aws_route_table" "private_route" {
  vpc_id = aws_vpc.dollar_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id # NAT Gateway
  }
}

#Associate route table for private subnet to use NAT gateway

resource "aws_route_table_association" "private_route_association" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private_route.id
}

#Cloud NAT Gateway

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_eip.id # NAT EIP
  subnet_id     = aws_subnet.public.id
  depends_on = [
    aws_internet_gateway.nat_ig
  ]
}

#Enable NAT for Private Subnet

resource "aws_route" "p_route" {
  route_table_id         = aws_route_table.private_route.id
  destination_cidr_block = "0.0.0.0/16"
  nat_gateway_id         = aws_nat_gateway.nat_gateway.id
}

#setting up Security group

resource "aws_security_group" "secure_group" {
  name        = "secure_group"
  description = "Allow limited traffic"
  vpc_id      = aws_vpc.dollar_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#Deploy ec2 instance on private Subnet and check internet access

resource "aws_instance" "vm_ubuntu" {
  ami                    = "ami-02eb7a4783e7e9317" # Ubuntu:latest
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.secure_group.id]
  key_name               = "assignment"
  tags = {
    Name = "vm_ubuntu"
  }
  provisioner "remote-exec" {
    inline = [
      "if ping -q -c 1 -W 1 google.com >/dev/null; then echo \"Internet not available\"; else  echo \"Internet available\"; fi"
    ]
    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = "aws_instance.vm_ubuntu.public_ip"
      private_key = file("assignment.pem")
    }
  }
}

