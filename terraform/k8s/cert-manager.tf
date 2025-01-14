# Zone permissions
data "cloudflare_api_token_permission_groups" "all" {}

resource "cloudflare_api_token" "cert_manager" {
  name = "cert_manager_${var.environment}"
  policy {
    permission_groups = [
      data.cloudflare_api_token_permission_groups.all.zone["DNS Write"],
      data.cloudflare_api_token_permission_groups.all.zone["Zone Read"]
    ]
    resources = {
      "com.cloudflare.api.account.zone.*" = "*"
    }
  }
}

resource "bitwarden_secret" "cert-manager" {
  key        = "CERT_MANAGER_CLOUDFLARE_TOKEN"
  value      = cloudflare_api_token.cert_manager.value
  note       = "Used for ACME challenges by cert-manager"
  project_id = var.bitwarden_project_id
}
