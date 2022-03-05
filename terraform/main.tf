provider "aws" {
  region = "ap-northeast-1"
}

# VMイメージ

variable "amazon_linux2_images" {
  default = {
    ap-northeast-1 = "ami-08a8688fb7eacb171"
  }
}

variable "ubuntu2004_images" {
  default = {
    ap-northeast-1 = "ami-088da9557aae42f39"
  }
}

# VPC

resource "aws_vpc" "myVPC" {
  cidr_block           = "10.1.0.0/16"
  instance_tenancy     = "default"
  enable_dns_support   = "true"
  enable_dns_hostnames = "false"
  tags = {
    Name = "myVPC"
  }
}

# インターネットゲートウェイ

resource "aws_internet_gateway" "myGW" {
  vpc_id = aws_vpc.myVPC.id
}

# サブネット

resource "aws_subnet" "public-a" {
  vpc_id            = aws_vpc.myVPC.id
  cidr_block        = "10.1.1.0/24"
  availability_zone = "ap-northeast-1a"
}

# ルートテーブル

resource "aws_route_table" "public-route" {
  vpc_id = aws_vpc.myVPC.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myGW.id
  }
}

# サブネットとルートテーブルの紐づけ

resource "aws_route_table_association" "puclic-a" {
  subnet_id      = aws_subnet.public-a.id
  route_table_id = aws_route_table.public-route.id
}

# FWルール

resource "aws_security_group" "admin" {
  name        = "admin"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.myVPC.id
  ingress {
    from_port   = 22
    to_port     = 22
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

resource "aws_security_group" "local_ssh" {
  name        = "local_ssh"
  description = "Allow SSH local traffic"
  vpc_id      = aws_vpc.myVPC.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.1.1.0/24"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "ansible_host" {
  ami           = var.amazon_linux2_images.ap-northeast-1
  instance_type = "t2.micro"
  key_name      = "tf-key"
  vpc_security_group_ids = [
    "${aws_security_group.admin.id}"
  ]
  subnet_id                   = aws_subnet.public-a.id
  private_ip                  = "10.1.1.10"
  associate_public_ip_address = "true"
  root_block_device {
    volume_type = "gp2"
    volume_size = "8"
  }
  tags = {
    Name = "ansible_host"
  }
}

module "ansible_target" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 3.0"

  for_each = toset(["first"])

  name = "instance-${each.key}"

  ami                    = var.ubuntu2004_images.ap-northeast-1
  key_name               = "tf-key"
  vpc_security_group_ids = ["${aws_security_group.admin.id}"]
  subnet_id              = aws_subnet.public-a.id
  private_ip                  = "10.1.1.11"

  instance_type               = "t2.micro"
  associate_public_ip_address = "true"
  root_block_device = [{
    volume_type = "gp2"
    volume_size = "8"
  }]
  tags = {
    Name = "ansible_target_first"
  }
}

resource "aws_key_pair" "tf-key" {
  key_name   = "tf-key"
  public_key = file("./id_rsa.pub") # ToDo: ssh-keygen -t rsa -b 4096したヤツを使うとpermisson denyになる
}