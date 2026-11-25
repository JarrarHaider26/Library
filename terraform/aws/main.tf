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

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["137112412989"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-6.1-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_security_group" "library_ec2" {
  name        = "library-ec2-sg"
  description = "Allow Library API and SSH/SSM-managed access"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Library API"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  ingress {
    description = "SSH (optional, restrict to your IP)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "library-ec2-sg"
  }
}

resource "aws_iam_role" "library_ec2" {
  name = "library-ec2-ssm-role"

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
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.library_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "library_ec2" {
  name = "library-ec2-profile"
  role = aws_iam_role.library_ec2.name
}

resource "aws_instance" "library_ec2" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = sort(data.aws_subnets.default.ids)[0]
  vpc_security_group_ids      = [aws_security_group.library_ec2.id]
  iam_instance_profile        = aws_iam_instance_profile.library_ec2.name
  associate_public_ip_address = true
  user_data_replace_on_change = true

  user_data = templatefile("${path.module}/bootstrap-docker.sh", {
    repo_url    = var.repo_url
    repo_branch = var.repo_branch
    secret_key  = var.app_secret_key
    algorithm   = var.app_algorithm
  })

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = {
    Name = "library-ec2"
  }
}

variable "aws_region" {
  description = "AWS region for the EC2 deployment."
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS CLI profile used by Terraform."
  type        = string
  default     = "default"
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.small"
}

variable "allowed_cidr" {
  description = "CIDR allowed to access the API/SSH, e.g. your public IP/32."
  type        = string
}

variable "repo_url" {
  description = "Git repository URL containing this project."
  type        = string
}

variable "repo_branch" {
  description = "Git branch to deploy."
  type        = string
  default     = "main"
}

variable "app_secret_key" {
  description = "SECRET_KEY for JWT signing."
  type        = string
  sensitive   = true
}

variable "app_algorithm" {
  description = "JWT algorithm."
  type        = string
  default     = "HS256"
}

output "instance_id" {
  value = aws_instance.library_ec2.id
}

output "public_ip" {
  value = aws_instance.library_ec2.public_ip
}

output "library_api_url" {
  value = "http://${aws_instance.library_ec2.public_ip}:8000"
}

output "library_api_docs_url" {
  value = "http://${aws_instance.library_ec2.public_ip}:8000/docs"
}

output "health_url" {
  value = "http://${aws_instance.library_ec2.public_ip}:8000/health"
}

output "ssm_session_command" {
  value = "aws ssm start-session --target ${aws_instance.library_ec2.id} --region ${var.aws_region} --profile ${var.aws_profile}"
}
