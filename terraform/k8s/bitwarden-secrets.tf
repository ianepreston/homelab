resource "bitwarden_secret" "test" {
  key        = "TERRAFORM_TEST_SECRET"
  value      = "hello from terraform"
  note       = "Do I have to put something here?"
  project_id = var.bitwarden_project_id
}
