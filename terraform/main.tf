provider "aws" {
    region = "ap-northeast-1"
}

# VMイメージ

variable "images" {
    default = {
        ap-northeast-1 = "ami-08a8688fb7eacb171"
    }
}

# VPC

resource "aws_vpc" "myVPC" {
    cidr_block = "10.1.0.0/16"
    instance_tenancy = "default"
    enable_dns_support = "true"
    enable_dns_hostnames = "false"
    tags = {
      Name = "myVPC"
    }
}

# インターネットゲートウェイ

resource "aws_internet_gateway" "myGW" {
    vpc_id = "${aws_vpc.myVPC.id}"
}

# ルートテーブル

resource "aws_subnet" "public-a" {
    vpc_id = "${aws_vpc.myVPC.id}"
    cidr_block = "10.1.1.0/24"
    availability_zone = "ap-northeast-1a"
}

resource "aws_route_table" "public-route" {
    vpc_id = "${aws_vpc.myVPC.id}"
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.myGW.id}"
    }
}

# ルートテーブル

resource "aws_route_table_association" "puclic-a" {
    subnet_id = "${aws_subnet.public-a.id}"
    route_table_id = "${aws_route_table.public-route.id}"
}

# FWルール

resource "aws_security_group" "admin" {
    name = "admin"
    description = "Allow SSH inbound traffic"
    vpc_id = "${aws_vpc.myVPC.id}"
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_instance" "tf-instance" {
    ami = "${var.images.ap-northeast-1}"
    instance_type = "t2.micro"
    key_name = "tf-key"
    vpc_security_group_ids = [
      "${aws_security_group.admin.id}"
    ]
    subnet_id = "${aws_subnet.public-a.id}"
    associate_public_ip_address = "true"
    root_block_device {
      volume_type = "gp2"
      volume_size = "8"
    }
    tags = {
        Name = "tf-instance"
    }
}

output "public_ip_of_tf-instance" {
  value = "${aws_instance.tf-instance.public_ip}"
}

resource "aws_key_pair" "tf-key" {
  key_name   = "tf-key"
  public_key = "${file("./id_rsa.pub")}"  # ToDo: ssh-keygen -t rsa -b 4096したヤツを使うとpermisson denyになる
}