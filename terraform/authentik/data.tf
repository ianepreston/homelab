data "authentik_certificate_key_pair" "generated" {
  name = "authentik Self-signed Certificate"
}

data "authentik_flow" "default-auth" {
  slug = "default-provider-authorization-implicit-consent"
}

data "authentik_flow" "default-authn" {
  slug = "default-authentication-flow"
}
data "authentik_flow" "default-invalidation" {
  slug = "default-provider-invalidation-flow"
}

data "authentik_service_connection_kubernetes" "local" {
  name = "Local Kubernetes Cluster"
}

data "authentik_property_mapping_provider_scope" "oauth2" {
  managed_list = [
    "goauthentik.io/providers/oauth2/scope-openid",
    "goauthentik.io/providers/oauth2/scope-email",
    "goauthentik.io/providers/oauth2/scope-profile"
  ]
}
