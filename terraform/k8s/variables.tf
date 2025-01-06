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
