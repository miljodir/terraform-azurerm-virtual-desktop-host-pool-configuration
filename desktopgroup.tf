resource "azurerm_virtual_desktop_application_group" "desktop" {
  count               = local.create_desktop
  resource_group_name = azurerm_resource_group.main.name
  host_pool_id        = azapi_resource.avd_host_pool.id
  location            = var.hostpool_location
  type                = "Desktop"
  name                = lower("${azapi_resource.avd_host_pool.name}-${var.desktop_application_group_name}")
  friendly_name       = var.desktop_group_friendly_name == null ? lower("${azapi_resource.avd_host_pool.name}-${var.desktop_application_group_name}") : var.desktop_group_friendly_name
  description         = var.desktop_group_description == null ? lower("${azapi_resource.avd_host_pool.name}-${var.desktop_application_group_name}") : var.desktop_group_description
}

data "azuread_users" "desktop_users" {
  count                = local.create_desktop
  user_principal_names = var.desktop_users
}

data "azuread_groups" "desktop_groups" {
  count          = local.create_desktop
  display_names  = var.desktop_groups
  ignore_missing = true
}

resource "azuread_group" "desktop_users" {
  count            = local.create_desktop
  display_name     = "az rbac ${azurerm_virtual_desktop_application_group.desktop[0].name} users"
  security_enabled = true
  members          = concat(data.azuread_users.desktop_users[0].object_ids, data.azuread_groups.desktop_groups[0].object_ids)
}

resource "azurerm_role_assignment" "desktop_avd_user" {
  count                = local.create_desktop
  scope                = azurerm_virtual_desktop_application_group.desktop[0].id
  role_definition_name = "Desktop Virtualization User"
  principal_type       = "Group"
  principal_id         = azuread_group.desktop_users[0].object_id
}

resource "azurerm_role_assignment" "desktop_vmlogin" {
  count                = local.create_desktop
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Virtual Machine User Login"
  principal_type       = "Group"
  principal_id         = azuread_group.desktop_users[0].object_id
}

resource "azurerm_virtual_desktop_workspace_application_group_association" "desktop" {
  count                = local.create_desktop
  application_group_id = azurerm_virtual_desktop_application_group.desktop[0].id
  workspace_id         = azurerm_virtual_desktop_workspace.main.id
}
