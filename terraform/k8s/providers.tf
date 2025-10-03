terraform {
  cloud {

    organization = "ianpreston"

    workspaces {
      tags    = ["k8s"]
      project = "Homelab"
    }
  }
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "3.7.2"
    }
    bitwarden = {
      source  = "maxlaverse/bitwarden"
      version = ">= 0.12.1"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.11.0"
    }
  }
}

provider "bitwarden" {
  access_token = var.bitwarden_access_token
  experimental {
    embedded_client = true
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
