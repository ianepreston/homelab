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

variable "CLUSTER_DOMAIN" {
  description = "Which cluster we're configuring"
  type        = string
}

variable "AUTHENTIK_TOKEN_SECRET_ID" {
  description = "Where to retrieve the authentik token from in BWS"
  type        = string
  sensitive   = true
}

variable "email" {
  description = "email address for notifications or whatever"
  type        = string
  sensitive   = true
}


