resource "authentik_provider_proxy" "proxy" {
  for_each           = local.proxy_apps
  name               = each.key
  internal_host      = each.value.internal_host
  external_host      = each.value.launch_url
  mode               = "forward_single"
  authorization_flow = data.authentik_flow.default-auth.id
  invalidation_flow  = data.authentik_flow.default-invalidation.id
}

resource "authentik_application" "proxy" {
  for_each          = local.proxy_apps
  name              = each.key
  slug              = lower(each.key)
  protocol_provider = authentik_provider_proxy.proxy[each.key].id
  group             = local.authentik_groups[each.value.group].name
  meta_icon         = each.value.icon_url
  meta_launch_url   = each.value.launch_url
}

resource "authentik_outpost" "proxy" {
  name               = "proxy-outpost"
  type               = "proxy"
  protocol_providers = [for p in authentik_provider_proxy.proxy : p.id]
  service_connection = data.authentik_service_connection_kubernetes.local.id
  config = jsonencode({
    kubernetes_namespace    = "authentik"
    authentik_host          = "http://authentik-server.authentik.svc.cluster.local"
    authentik_host_insecure = true
    authentik_host_browser  = "https://authentik.${var.CLUSTER_DOMAIN}"
  })
}

resource "authentik_policy_binding" "proxy" {
  for_each = local.proxy_apps
  target   = authentik_application.proxy[each.key].uuid
  group    = authentik_group.default[each.value.group].id
  order    = 0
}

data "bitwarden_secret" "oauth_client_id" {
  for_each = local.oauth_apps
  key      = "${upper(each.key)}_CLIENT_ID"
}

data "bitwarden_secret" "oauth_client_secret" {
  for_each = local.oauth_apps
  key      = "${upper(each.key)}_CLIENT_SECRET"
}

resource "authentik_provider_oauth2" "oauth2" {
  for_each              = local.oauth_apps
  name                  = each.key
  client_id             = data.bitwarden_secret.oauth_client_id[each.key].value
  client_secret         = data.bitwarden_secret.oauth_client_secret[each.key].value
  authorization_flow    = data.authentik_flow.default-auth.id
  authentication_flow   = data.authentik_flow.default-authn.id
  invalidation_flow     = data.authentik_flow.default-invalidation.id
  property_mappings     = each.value.property_mappings
  access_token_validity = "hours=4"
  signing_key           = data.authentik_certificate_key_pair.generated.id
  allowed_redirect_uris = [
    {
      matching_mode = "strict",
      url           = each.value.redirect_uri,
    }
  ]
}

resource "authentik_application" "application" {
  for_each           = local.oauth_apps
  name               = each.key
  slug               = lower(each.key)
  protocol_provider  = authentik_provider_oauth2.oauth2[each.key].id
  group              = authentik_group.default[each.value.group].name
  open_in_new_tab    = true
  meta_icon          = each.value.icon_url
  meta_launch_url    = each.value.launch_url
  policy_engine_mode = "all"
}
