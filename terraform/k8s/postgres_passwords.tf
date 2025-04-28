resource "random_password" "postgres_miniflux" {
  length  = 16
  special = true
}
resource "bitwarden_secret" "postgres_miniflux" {
  key        = "POSTGRES_MINIFLUX_PASS"
  value      = random_password.postgres_miniflux.result
  note       = "Password for miniflux postgres server"
  project_id = var.bitwarden_project_id
}
