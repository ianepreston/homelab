locals {
  default_property_mappings = data.authentik_property_mapping_provider_scope.oauth2.ids
  authentik_groups = {
    downloads      = { name = "Downloads" }
    grafana_admins = { name = "Grafana Admins" }
    home           = { name = "Home" }
    infrastructure = { name = "Infrastructure" }
    media          = { name = "Media" }
    monitoring     = { name = "Monitoring" }
    users          = { name = "Users" }
  }
  proxy_apps = {
    Longhorn = {
      group         = "infrastructure"
      icon_url      = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/png/longhorn.png"
      launch_url    = "https://longhorn.${var.CLUSTER_DOMAIN}"
      internal_host = "http://longhorn-frontend.longhorn-system.svc.cluster.local"
    }
  }
  oauth_apps = {
    miniflux = {
      group             = "media"
      icon_url          = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/png/miniflux.png"
      redirect_uri      = "https://miniflux.${var.CLUSTER_DOMAIN}/oauth2/oidc/callback"
      launch_url        = "https://miniflux.${var.CLUSTER_DOMAIN}"
      property_mappings = local.default_property_mappings
    }
  }
}
