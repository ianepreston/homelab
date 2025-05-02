resource "bitwarden_secret" "subdomain" {
  key        = "SUBDOMAIN"
  value      = var.subdomain
  note       = "Argo will substitute this into ingress specs"
  project_id = var.bitwarden_project_id
}
