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
    AlertManager = {
      group         = "monitoring"
      icon_url      = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/png/alertmanager.png"
      launch_url    = "https://alertmanager.${var.CLUSTER_DOMAIN}"
      internal_host = "http://kube-prometheus-stack-alertmanager.monitoring.svc.cluster.local"
    }
    Longhorn = {
      group         = "infrastructure"
      icon_url      = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/png/longhorn.png"
      launch_url    = "https://longhorn.${var.CLUSTER_DOMAIN}"
      internal_host = "http://longhorn-frontend.longhorn-system.svc.cluster.local"
    }
    Prometheus = {
      group         = "monitoring"
      icon_url      = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/png/prometheus.png"
      launch_url    = "https://prometheus.${var.CLUSTER_DOMAIN}"
      internal_host = "http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local"
    }
  }
  oauth_apps = {
    Grafana = {
      group             = "monitoring"
      icon_url          = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/png/grafana.png"
      redirect_uri      = "https://grafana.${var.CLUSTER_DOMAIN}/login/generic_oauth"
      launch_url        = "https://grafana.${var.CLUSTER_DOMAIN}/login/generic_oauth"
      property_mappings = local.default_property_mappings
    }
  }
}
