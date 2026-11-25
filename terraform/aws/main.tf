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

resource "aws_security_group" "k3s_demo" {
  name        = "library-k3s-demo"
  description = "IP-restricted access to Library demo services"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Argo CD HTTPS UI"
    from_port   = 30443
    to_port     = 30443
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  ingress {
    description = "Grafana UI"
    from_port   = 30300
    to_port     = 30300
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  ingress {
    description = "Prometheus UI"
    from_port   = 30901
    to_port     = 30901
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  ingress {
    description = "Library API"
    from_port   = 30800
    to_port     = 30800
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "k3s_demo" {
  name = "library-k3s-demo-ssm"

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
  role       = aws_iam_role.k3s_demo.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "k3s_demo" {
  name = "library-k3s-demo"
  role = aws_iam_role.k3s_demo.name
}

resource "aws_instance" "k3s_demo" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = "t3.large"
  subnet_id                   = sort(data.aws_subnets.default.ids)[0]
  vpc_security_group_ids      = [aws_security_group.k3s_demo.id]
  iam_instance_profile        = aws_iam_instance_profile.k3s_demo.name
  associate_public_ip_address = true
  user_data                   = file("${path.module}/bootstrap-k3s.sh")
  user_data_replace_on_change = true

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = {
    Name = "library-k3s-demo"
  }
}

variable "aws_region" {
  description = "AWS region for the K3s demo host."
  type        = string
  default     = "ap-southeast-2"
}

variable "aws_profile" {
  description = "AWS CLI profile used by Terraform."
  type        = string
  default     = "terraform"
}

variable "admin_cidr" {
  description = "Your public IPv4 address in CIDR notation, for example 203.0.113.10/32."
  type        = string
}

output "cluster_name" {
  value = "k3s-on-ec2"
}

output "instance_id" {
  value = aws_instance.k3s_demo.id
}

output "public_ip" {
  value = aws_instance.k3s_demo.public_ip
}

output "argocd_url" {
  value = "https://${aws_instance.k3s_demo.public_ip}:30443"
}

output "grafana_url" {
  value = "http://${aws_instance.k3s_demo.public_ip}:30300"
}

output "prometheus_url" {
  value = "http://${aws_instance.k3s_demo.public_ip}:30901"
}

output "library_api_docs_url" {
  value = "http://${aws_instance.k3s_demo.public_ip}:30800/docs"
}

output "ssm_session_command" {
  value = "aws ssm start-session --target ${aws_instance.k3s_demo.id} --region ${var.aws_region} --profile ${var.aws_profile}"
}
