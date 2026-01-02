# Zone permissions
data "cloudflare_api_token_permission_groups_list" "all" {}

locals {
  dns_write = element(
    data.cloudflare_api_token_permission_groups_list.all.result,
    index(
      data.cloudflare_api_token_permission_groups_list.all.result.*.name,
      "DNS Write"
    )
  )
  zone_read = element(
    data.cloudflare_api_token_permission_groups_list.all.result,
    index(
      data.cloudflare_api_token_permission_groups_list.all.result.*.name,
      "Zone Read"
    )
  )
}

resource "cloudflare_api_token" "cert_manager" {
  name = "cert_manager_${var.environment}"
  policies = [{
    effect = "allow"
    permission_groups = [
      { id = local.zone_read.id },
      { id = local.dns_write.id },
    ]
    resources = jsonencode({
      "com.cloudflare.api.account.zone.*" = "*"
    })
  }]
  status = "active"
}

resource "bitwarden_secret" "cert-manager" {
  key        = "CERT_MANAGER_CLOUDFLARE_TOKEN"
  value      = cloudflare_api_token.cert_manager.value
  note       = "Used for ACME challenges by cert-manager"
  project_id = var.bitwarden_project_id
}
