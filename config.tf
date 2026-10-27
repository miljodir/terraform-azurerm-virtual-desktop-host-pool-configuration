# Use azapi as this resource is still in preview and not available in terraform azurerm provider yet
moved {
  from = azapi_resource.avd_host_config
  to   = azapi_resource.avd_host_config[0]
}

resource "azapi_resource" "avd_host_config" {
  count = var.hostconfig_provisioning_enabled ? 1 : 0

  type      = "Microsoft.DesktopVirtualization/hostPools/sessionHostConfigurations@2025-03-01-preview"
  name      = "default"
  parent_id = azapi_resource.avd_host_pool.id

  body = {
    properties = merge({
      diskInfo = {
        managedDisk = {
          type = var.hostconfig_disk_type
        }
      }
      domainInfo = {
        joinType = "AzureActiveDirectory"
        azureActiveDirectoryInfo = {
          mdmProviderGuid = var.hostconfig_mdm_guid
        }
      }
      imageInfo = {
        type = "Marketplace"
        marketplaceInfo = {
          publisher    = var.hostconfig_image_publisher
          offer        = var.hostconfig_image_offer
          sku          = local.use_avd_sku
          exactVersion = local.use_avd_sku_version
        }
      }
      networkInfo = {
        subnetId = var.subnet_id
      }
      securityInfo = {
        type              = var.hostconfig_security_type
        secureBootEnabled = var.hostconfig_secure_boot_enabled
        vTpmEnabled       = var.hostconfig_vtpm_enabled
      }
      vmAdminCredentials = {
        usernameKeyVaultSecretUri = var.kv_username_secret_id != null ? var.kv_username_secret_id : azurerm_key_vault_secret.host_pool_admin_username[0].id
        passwordKeyVaultSecretUri = var.kv_password_secret_id != null ? var.kv_password_secret_id : azurerm_key_vault_secret.host_pool_admin_password[0].id
      }
      vmLocation      = var.location
      vmNamePrefix    = local.vm_name_prefix
      vmResourceGroup = azurerm_resource_group.main.name
      vmSizeId        = var.hostconfig_vm_size
      }, var.hostconfig_custom_configuration_script_url == null ? {} : {
      customConfigurationScriptUrl = var.hostconfig_custom_configuration_script_url
    })
  }

  depends_on = [
    azurerm_role_assignment.pool_compute_contributor,
    azurerm_role_assignment.avd_network_contributor,
    azurerm_role_assignment.pool_network_contributor,
    azurerm_role_assignment.pool_vault_secrets_user
  ]
}
