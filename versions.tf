terraform {
  required_version = ">= 1.0.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.33"
    }
    kind = {
      source  = "tehcyx/kind"
      version = ">= 0.6"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.16"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9.1"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.4.0"
    }
  }
}