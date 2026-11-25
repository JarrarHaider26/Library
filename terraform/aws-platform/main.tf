terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

data "aws_eks_cluster" "target" {
  name = var.cluster_name
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.target.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.target.certificate_authority[0].data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks", "get-token",
        "--cluster-name", var.cluster_name,
        "--region", var.aws_region,
        "--profile", var.aws_profile,
      ]
    }
  }
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "10.20.0"
  namespace        = "argocd"
  create_namespace = true
  wait             = true
  timeout          = 900

  values = [yamlencode({
    server = {
      service = {
        type = "ClusterIP"
      }
    }
  })]
}

resource "helm_release" "monitoring" {
  name             = "monitoring"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = "93.11.0"
  namespace        = "monitoring"
  create_namespace = true
  wait             = true
  timeout          = 900

  values = [yamlencode({
    grafana = {
      persistence = {
        enabled = false
      }
    }
    prometheus = {
      prometheusSpec = {
        retention                               = "24h"
        retentionSize                           = "1GB"
        serviceMonitorSelectorNilUsesHelmValues = false
        serviceMonitorNamespaceSelector         = {}
        ruleSelectorNilUsesHelmValues           = false
        ruleNamespaceSelector                   = {}
        storageSpec                             = {}
      }
    }
    alertmanager = {
      alertmanagerSpec = {
        storage = {}
      }
    }
  })]
}

variable "aws_region" {
  description = "AWS region containing the EKS cluster."
  type        = string
  default     = "ap-southeast-2"
}

variable "aws_profile" {
  description = "AWS CLI profile used by Terraform."
  type        = string
  default     = "terraform"
}

variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
  default     = "library-eks"
}

output "argocd_port_forward" {
  value = "kubectl port-forward -n argocd svc/argocd-server 8443:443"
}

output "grafana_port_forward" {
  value = "kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80"
}

output "prometheus_port_forward" {
  value = "kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090"
}
