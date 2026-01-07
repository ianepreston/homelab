data "authentik_group" "admins" {
  name = "authentik Admins"
}

resource "authentik_group" "default" {
  for_each     = local.authentik_groups
  name         = each.value.name
  is_superuser = false
}

# resource "authentik_policy_binding" "application_policy_binding" {
#   for_each = local.applications
#
#   target = authentik_application.application[each.key].uuid
#   group  = authentik_group.default[each.value.group].id
#   order  = 0
# }

resource "authentik_user" "ian" {
  username = "iPreston"
  name     = "Ian Preston"
  email    = var.email
  groups = concat(
    [data.authentik_group.admins.id],
    values(authentik_group.default)[*].id
  )
}
