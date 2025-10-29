resource "azurerm_virtual_desktop_application_group" "app" {
  count               = local.create_app
  resource_group_name = azurerm_resource_group.main.name
  host_pool_id        = azapi_resource.avd_host_pool.id
  location            = var.hostpool_location
  type                = "RemoteApp"
  name                = lower("${azapi_resource.avd_host_pool.name}-${var.app_application_group_name}")
  friendly_name       = var.app_group_friendly_name == null ? lower("${azapi_resource.avd_host_pool.name}-${var.app_application_group_name}") : var.app_group_friendly_name
  description         = var.app_group_description == null ? lower("${azapi_resource.avd_host_pool.name}-${var.app_application_group_name}") : var.app_group_description
}

data "azuread_users" "app_users" {
  count                = local.create_app
  user_principal_names = var.app_users
}

data "azuread_groups" "app_groups" {
  count          = local.create_app
  display_names  = var.app_groups
  ignore_missing = true
}

resource "azuread_group" "app_users" {
  count            = local.create_app
  display_name     = "az rbac ${azurerm_virtual_desktop_application_group.app[0].name} users"
  security_enabled = true
  members          = concat(data.azuread_users.app_users[0].object_ids, data.azuread_groups.app_groups[0].object_ids)
}

resource "azurerm_role_assignment" "app_avd_user" {
  count                = local.create_app
  scope                = azurerm_virtual_desktop_application_group.app[0].id
  role_definition_name = "Desktop Virtualization User"
  principal_type       = "Group"
  principal_id         = azuread_group.app_users[0].object_id
}

resource "azurerm_role_assignment" "app_vmlogin" {
  count                = local.create_app
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Virtual Machine User Login"
  principal_type       = "Group"
  principal_id         = azuread_group.app_users[0].object_id
}

resource "azurerm_virtual_desktop_workspace_application_group_association" "app" {
  count                = local.create_app
  application_group_id = azurerm_virtual_desktop_application_group.app[0].id
  workspace_id         = azurerm_virtual_desktop_workspace.main.id
}

resource "azurerm_virtual_desktop_application" "apps" {
  for_each                     = var.applications
  application_group_id         = azurerm_virtual_desktop_application_group.app[0].id
  name                         = each.key
  path                         = each.value["path"]
  friendly_name                = try(each.value["friendly_name"], null)
  description                  = try(each.value["description"], null)
  command_line_argument_policy = try(each.value["command_line_argument_policy"], "DoNotAllow")
  command_line_arguments       = try(each.value["command_line_arguments"], null)
  show_in_portal               = try(each.value["show_in_portal"], true)
  icon_path                    = try(each.value["icon_path"], null)
  icon_index                   = try(each.value["icon_index"], null)
}
