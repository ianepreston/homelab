terraform {
  cloud {
    organization = "ianpreston"
    workspaces {
      name = "homelab"
    }
  }
  required_providers {
    xenorchestra = {
      source  = "terra-farm/xenorchestra"
      version = "0.26.1"
    }
  }
}
