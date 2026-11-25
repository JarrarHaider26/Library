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

output "role_name" {
  value = aws_iam_role.demo_role.name
}

output "role_arn" {
  value = aws_iam_role.demo_role.arn
}
