output "resource_group" {
  value = azurerm_resource_group.main
}

output "workspace" {
  value = azurerm_virtual_desktop_workspace.main
}

output "hostpool" {
  value = azapi_resource.avd_host_pool
}

output "hostconfig" {
  value = azapi_resource.avd_host_config
}

output "key_vault_id" {
  value = var.key_vault_id != null ? var.key_vault_id : azurerm_key_vault.main[0].id
}

output "desktop_group" {
  value = local.create_desktop ? azuread_group.desktop_users[0] : null
}

output "app_group" {
  value = local.create_app ? azuread_group.app_users[0] : null
}
