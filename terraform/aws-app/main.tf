terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38"
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

provider "kubernetes" {
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

resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = "gp3"
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    type      = "gp3"
    encrypted = "true"
    fsType    = "ext4"
  }
}

resource "kubernetes_manifest" "library_application" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "library-app"
      namespace = "argocd"
    }
    spec = {
      project = "default"
      source = {
        repoURL        = "https://github.com/JarrarHaider26/Library.git"
        targetRevision = "main"
        path           = "helm-library"
        helm = {
          parameters = [
            {
              name  = "app.service.type"
              value = "ClusterIP"
            },
            {
              name  = "postgres.pvc.storageClassName"
              value = "gp3"
            }
          ]
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "default"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
      }
    }
  }

  depends_on = [kubernetes_storage_class_v1.gp3]
}

resource "kubernetes_manifest" "library_service_monitor" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "library-api"
      namespace = "monitoring"
      labels = {
        release = "monitoring"
      }
    }
    spec = {
      endpoints = [
        {
          interval = "15s"
          path     = "/metrics"
          port     = "http"
        }
      ]
      namespaceSelector = {
        matchNames = ["default"]
      }
      selector = {
        matchLabels = {
          app = "library-api"
        }
      }
    }
  }
}

resource "kubernetes_manifest" "library_down_alert" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"
    metadata = {
      name      = "library-alerts"
      namespace = "monitoring"
      labels = {
        release = "monitoring"
      }
    }
    spec = {
      groups = [
        {
          name = "library-api"
          rules = [
            {
              alert = "LibraryApiDown"
              expr  = "up{namespace=\"default\",service=\"library-api-service\"} == 0"
              "for" = "1m"
              labels = {
                severity = "critical"
              }
              annotations = {
                summary     = "Library API is down"
                description = "Prometheus cannot scrape the Library API metrics endpoint."
              }
            }
          ]
        }
      ]
    }
  }
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
