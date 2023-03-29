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

    # default address is localhost. define a port to avoid random allocation.
    networking {
      api_server_address = "127.0.0.1"
      api_server_port = 6443
      # uncomment this when we're ready to install cilium
      #disable_default_cni = "true"
    }

    node {
      role = "control-plane"


      extra_mounts { 
        host_path      = "./share"
        container_path = "/share"
      }
 
      extra_port_mappings {
        container_port = 80
        host_port      = 8080
      }
      extra_port_mappings {
        container_port = 443
        host_port      = 8443
      }
    }
    node {
      role = "worker"
      
    }
    node {
      role = "worker"
    }

    containerd_config_patches = [
      <<-TOML
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:5000"]
          endpoint = ["http://kind-registry:5000"]
      TOML
    ]
  }
}
