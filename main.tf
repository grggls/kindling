terraform {
  required_providers {
    kind = {
      source = "tehcyx/kind"
      version = "0.0.16"
    }
  }
}

provider "kind" {
}

resource "kind_cluster" "kindle" {
  name = "kindle"
  node_image = "kindest/node:v1.23.4"
  wait_for_ready = "true"
  kind_config {
    kind = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"
    }
    node {
      role = "worker"
    }
    node {
      role = "worker"
    }
  }
}
