terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.3.0"
}

provider "aws" {
  region = var.aws_region
}

# -------------------------
# Ubuntu 22.04 AMI
# -------------------------
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# -------------------------
# ECR Repository for Strapi
# -------------------------
resource "aws_ecr_repository" "strapi" {
  name                 = "strapi-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }

  tags = {
    Name = "strapi-app-repository"
  }
}

# -------------------------
# EC2 Security Group
# -------------------------
resource "aws_security_group" "strapi_sg" {
  name        = "strapi-sg"
  description = "Allow Strapi and SSH"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = var.strapi_port
    to_port     = var.strapi_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# -------------------------
# RDS Security Group
# -------------------------
resource "aws_security_group" "strapi_rds_sg" {
  name        = "strapi-rds-sg-2"
  description = "Allow EC2 to access RDS"
  vpc_id      = data.aws_vpc.default.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# -------------------------
# Allow EC2 → RDS (REQUIRED FIX)
# -------------------------
resource "aws_security_group_rule" "allow_ec2_to_rds" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.strapi_rds_sg.id
  source_security_group_id = aws_security_group.strapi_sg.id
}

# -------------------------
# RDS Subnet Group
# -------------------------
resource "aws_db_subnet_group" "strapi_db_subnet_group" {
  name       = "strapi-db-subnet-group-2"
  subnet_ids = data.aws_subnets.default_subnets.ids
}

# -------------------------
# RDS PostgreSQL Instance (no engine_version → AWS auto-selects)
# -------------------------
resource "aws_db_instance" "strapi_rds" {
  identifier              = "strapi-db-2"
  allocated_storage       = 20
  engine                  = "postgres"
  instance_class          = "db.t3.micro"
  username                = "strapi"
  password                = "strapi123"
  db_name                 = "strapi_db"
  skip_final_snapshot     = true
  publicly_accessible     = false
  vpc_security_group_ids  = [aws_security_group.strapi_rds_sg.id]
  db_subnet_group_name    = aws_db_subnet_group.strapi_db_subnet_group.name
}

# -------------------------
# USER DATA — Install Docker + Run Strapi (SSL FIX APPLIED)
# -------------------------
locals {
  user_data = <<-EOF
              #!/bin/bash

              # Configure SSH access for ubuntu user
              mkdir -p /home/ubuntu/.ssh
              echo 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC9CNcCbiBh4KXdD9ELlNhP0MF5WQ/hJimRnQpjloNFRGQ2xLsPx/BemCh+jxn4OT4UNnXAIWGt21O47wufVOr/A6VVgqHPuIolMA7LZ8+Y0eXvyBptwmH4bDcPY11e652KrRh4ZOxbXvV61hissrKKhRhHoECr+jo2CHx7rai1M3qHT3VKQtoKG5lB4rwHpIo8ky01sUIXvKz0pT95nrp8SbtuoOnv2DI6w7/BGkAfAPdw48/RJx4G+q1kQm71xiO8DJRi07lO/F+6ZO+OWMM1foTA/wi2fHQBf3D8FeqkSvQsj5LV5fgOBQP5DabfJwWQnBobfTnyj5XSTOXSbxZ9UxoPQaFJD6mSkIS66gBClajNfgid+K46Hxv90fW5xgj8k4VFBjVtmCVoN3LBSdtXuRro7OjnUOpwxL2gBcsCZHtmPPQyuFVi4gejNB7jJLhXUn6GUbB+9h9AURQn8rKxJMbos8UehIBSfk7vcRtpRMBhY4JItqELXaSAL2Qn01z/MnGX/R+9LpMc5Za2QIJoCc2YVCiUViHSXw3G9+/0IqoYT+1poVj8HrAZUFQHx0ah276hoPs4mQO857kWqNVd5QNhUwEkpOw+61e7+ap/YBgx0MYC2/O2YoPPtcrj62GmCoWeLnZ1LJRW8xKqpt4q6TG6cMZzY1qPdmk4G6wo2Q== strapi-key' >> /home/ubuntu/.ssh/authorized_keys
              chmod 600 /home/ubuntu/.ssh/authorized_keys
              chown -R ubuntu:ubuntu /home/ubuntu/.ssh

              apt-get update -y
              apt-get install -y docker.io awscli

              systemctl start docker
              systemctl enable docker

              usermod -aG docker ubuntu

              # Configure AWS credentials for ECR access
              mkdir -p /home/ubuntu/.aws
              cat > /home/ubuntu/.aws/credentials <<AWSCREDS
[default]
aws_access_key_id = ${var.aws_access_key_id}
aws_secret_access_key = ${var.aws_secret_access_key}
AWSCREDS
              chmod 600 /home/ubuntu/.aws/credentials
              chown -R ubuntu:ubuntu /home/ubuntu/.aws

              # Login to ECR and pull Strapi image
              sudo -u ubuntu aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin 301782007642.dkr.ecr.ap-south-1.amazonaws.com
              docker pull ${var.docker_image}

              # Wait for RDS to be ready
              sleep 90

              # Run Strapi container with correct AWS RDS SSL env vars
              docker run -d -p 1337:1337 \
                --name strapi \
                -e DATABASE_CLIENT=postgres \
                -e DATABASE_HOST=${aws_db_instance.strapi_rds.address} \
                -e DATABASE_PORT=5432 \
                -e DATABASE_NAME=strapi_db \
                -e DATABASE_USERNAME=strapi \
                -e DATABASE_PASSWORD=strapi123 \
                -e DATABASE_SSL=true \
                -e DATABASE_SSL__REJECT_UNAUTHORIZED=false \
                -e HOST=0.0.0.0 \
                -e PORT=1337 \
                ${var.docker_image}
              EOF
}

# -------------------------
# EC2 INSTANCE
# -------------------------
resource "aws_instance" "strapi" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  vpc_security_group_ids      = [aws_security_group.strapi_sg.id]
  associate_public_ip_address = true

  user_data = local.user_data

  tags = {
    Name = "strapi-ubuntu-ec2"
  }
}

