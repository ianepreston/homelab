terraform {
  cloud {

    organization = "ianpreston"

    workspaces {
      tags    = ["authentik"]
      project = "Homelab"
    }
  }
  required_providers {
    bitwarden = {
      source  = "maxlaverse/bitwarden"
      version = ">= 0.12.1"
    }
    authentik = {
      source  = "goauthentik/authentik"
      version = "2025.12.0"
    }
  }
}

provider "bitwarden" {
  access_token = var.bitwarden_access_token
  experimental {
    embedded_client = true
  }
}

data "bitwarden_secret" "authentik_token" {
  id = var.AUTHENTIK_TOKEN_SECRET_ID
}

provider "authentik" {
  url   = "https://authentik.${var.CLUSTER_DOMAIN}"
  token = data.bitwarden_secret.authentik_token.value
}
