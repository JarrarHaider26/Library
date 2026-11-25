terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

resource "aws_iam_role" "demo_role" {
  name = var.role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Project = "Library-Terraform-Demo"
  }
}

resource "aws_s3_bucket" "demo_bucket" {
  bucket = var.bucket_name

  tags = {
    Project = "Library-Terraform-Demo"
  }
}

variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "ap-southeast-2"
}

variable "aws_profile" {
  description = "AWS CLI profile."
  type        = string
  default     = "ec2-profile"
}

variable "role_name" {
  description = "Name of the IAM role to create."
  type        = string
  default     = "library-terraform-demo-role"
}

variable "bucket_name" {
  description = "Name of the S3 bucket to create."
  type        = string
  default     = "library-terraform-demo-328238828695"
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.micro"
}

variable "instance_name" {
  description = "Name of the EC2 instance."
  type        = string
  default     = "library-terraform-demo-ec2"
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "demo_ec2_sg" {
  name        = "library-terraform-demo-ec2-sg"
  description = "Security group for Terraform demo EC2"
  vpc_id      = data.aws_vpc.default.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Project = "Library-Terraform-Demo"
  }
}

resource "aws_instance" "demo_ec2" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.demo_ec2_sg.id]

  tags = {
    Name    = var.instance_name
    Project = "Library-Terraform-Demo"
  }
}

output "role_name" {
  value = aws_iam_role.demo_role.name
}

output "role_arn" {
  value = aws_iam_role.demo_role.arn
}

output "bucket_name" {
  value = aws_s3_bucket.demo_bucket.bucket
}

output "bucket_arn" {
  value = aws_s3_bucket.demo_bucket.arn
}

output "ec2_instance_id" {
  value = aws_instance.demo_ec2.id
}

output "ec2_public_ip" {
  value = aws_instance.demo_ec2.public_ip
}
