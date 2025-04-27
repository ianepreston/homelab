terraform {
  cloud {

    organization = "ianpreston"

    workspaces {
      tags    = ["k8s"]
      project = "Homelab"
    }
  }
  required_providers {
    bitwarden = {
      source  = "maxlaverse/bitwarden"
      version = ">= 0.12.1"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = ">= 4.0"
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
