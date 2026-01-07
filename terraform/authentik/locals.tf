locals {
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
}
