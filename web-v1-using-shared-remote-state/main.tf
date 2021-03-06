#
# Create a VPC (from a module) and setup a webserver - v1
# 
# This takes our previous example of making a VPC from a module and then creates an
# EC2 Instance manually.
# 

# This is the provider we want to use / configure
provider "aws" {
  region = "${var.region}"
}

# This will allow us to use the existing VPC we made with another stack
data "terraform_remote_state" "vpc" {
  backend = "s3"
  config {
    bucket = "testing-new-s3-bucket"
    key    = "terraform"
    region = "eu-west-1"
  }
}


# This allows us to query AWS to get the "latest" of a certain AMI from them to use automatically
data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
}

# Our AWS Security group in our VPC (above)
resource "aws_security_group" "allow_ssh_and_http" {
  name        = "${var.env}-allow_ssh_and_http"
  description = "Allow SSH and HTTP"
  vpc_id = "${data.terraform_remote_state.vpc.vpc_id}"

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
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}


resource "aws_key_pair" "demo_keypair" {
    key_name = "${var.env}_keypair"
    public_key = "${file("~/.ssh/id_rsa.pub")}"
}

# This simply spins up a single webserver, for simplicity we'll spin it up in the public subnet
resource "aws_instance" "web" {
  ami                         = "${data.aws_ami.ubuntu.id}"
  instance_type               = "t2.micro"
  associate_public_ip_address = true
  key_name                    = "${aws_key_pair.demo_keypair.key_name}"
  subnet_id                   = "${data.terraform_remote_state.vpc.public_subnets[0]}"
  vpc_security_group_ids      = ["${aws_security_group.allow_ssh_and_http.id}"]
  tags                        = "${merge(local.tags, map("Name", "${var.env}-web-1"))}"
  user_data                   = "${file("../helpers/install-apache.sh")}"
}

# This is the "output" to print to the screen
output "webserver_public_ip" {
  description = "IP of our webserver"
  value       = "${aws_instance.web.public_ip}"
}

