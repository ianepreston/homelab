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
