resource "random_password" "authentik_bootstrap_password" {
  length  = 16
  special = true
}

resource "bitwarden_secret" "authentik_bootstrap_password" {
  key        = "AUTHENTIK_BOOTSTRAP_PASSWORD"
  value      = random_password.authentik_bootstrap_password.result
  note       = "Bootstrap admin pass for authentik"
  project_id = var.bitwarden_project_id
}

resource "random_password" "authentik_bootstrap_token" {
  length  = 16
  special = true
}

resource "bitwarden_secret" "authentik_bootstrap_token" {
  key        = "AUTHENTIK_BOOTSTRAP_TOKEN"
  value      = random_password.authentik_bootstrap_token.result
  note       = "Bootstrap admin token for authentik"
  project_id = var.bitwarden_project_id
}

resource "bitwarden_secret" "authentik_bootstrap_email" {
  key        = "AUTHENTIK_BOOTSTRAP_EMAIL"
  value      = var.email
  note       = "Email address for the akadmin user"
  project_id = var.bitwarden_project_id
}

