data "authentik_flow" "default-auth" {
  slug = "default-provider-authorization-implicit-consent"
}

data "authentik_flow" "default-invalidation" {
  slug = "default-provider-invalidation-flow"
}

data "authentik_service_connection_kubernetes" "local" {
  name = "Local Kubernetes Cluster"
}
