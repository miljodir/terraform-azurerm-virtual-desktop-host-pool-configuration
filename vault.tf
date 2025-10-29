resource "azurerm_key_vault" "main" {
  count = var.key_vault_id == null ? 1 : 0

  name                       = "${local.pool_name}-kv"
  location                   = var.location
  resource_group_name        = azurerm_resource_group.main.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  sku_name                   = "standard"
  rbac_authorization_enabled = true
}

resource "azurerm_key_vault_secret" "host_pool_admin_username" {
  count = var.key_vault_id == null ? 1 : 0

  key_vault_id = azurerm_key_vault.main[0].id
  name         = "host-pool-admin-username"
  value        = "sysadmin"
}

resource "random_password" "main" {
  count = var.key_vault_id == null ? 1 : 0

  length      = 24
  min_upper   = 4
  min_lower   = 2
  min_numeric = 4
  special     = false
}

resource "azurerm_key_vault_secret" "host_pool_admin_password" {
  count = var.key_vault_id == null ? 1 : 0

  key_vault_id = azurerm_key_vault.main[0].id
  name         = "host-pool-admin-password"
  value        = random_password.main[0].result
}

resource "azurerm_role_assignment" "pool_vault_secrets_user" {
  count                = var.assign_vault_permission ? 1 : 0
  scope                = var.key_vault_id != null ? var.key_vault_id : azurerm_key_vault.main[0].id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azapi_resource.avd_host_pool.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}