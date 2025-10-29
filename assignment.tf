resource "azurerm_role_assignment" "avd_network_contributor" {
  count                = var.assign_vnet_permission ? 1 : 0
  scope                = join("", slice(split("/subnets", var.subnet_id), 0, 1)) # extract vnet id from subnet id
  role_definition_name = "Network Contributor"
  principal_id         = "7b438d0e-4915-4fe9-b343-6837baf39748" #Azure Virtual Desktop app
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "pool_network_contributor" {
  count                = var.assign_vnet_permission ? 1 : 0
  scope                = join("", slice(split("/subnets", var.subnet_id), 0, 1)) # extract vnet id from subnet id
  role_definition_name = "Network Contributor"
  principal_id         = azapi_resource.avd_host_pool.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "pool_compute_contributor" {
  count                = var.assign_compute_permission ? 1 : 0
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Desktop Virtualization Virtual Machine Contributor"
  principal_id         = azapi_resource.avd_host_pool.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "pool_vault_secrets_user" {
  count                = var.assign_vault_permission ? 1 : 0
  scope                = var.key_vault_id != null ? var.key_vault_id : azurerm_key_vault.main[0].id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azapi_resource.avd_host_pool.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}