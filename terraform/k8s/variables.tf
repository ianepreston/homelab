variable "environment" {
  description = "What cluster this is being applied to"
  type        = string
}

variable "bitwarden_access_token" {
  description = "Access token for Bitwarden Secrets provider"
  type        = string
  sensitive   = true
}

variable "bitwarden_project_id" {
  description = "Which project ID we access secrets from"
  type        = string
  sensitive   = true
}

variable "cloudflare_api_token" {
  description = "API token for creating cloudflare resources"
  type        = string
  sensitive   = true
}
