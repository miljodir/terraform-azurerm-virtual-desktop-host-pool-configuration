# Using AzApi as the host pool resource in azurerm provider doesn't yet support managementType = "Automated"
resource "azapi_resource" "avd_host_pool" {
  type      = "Microsoft.DesktopVirtualization/hostPools@2025-03-01-preview"
  name      = local.pool_name
  parent_id = azurerm_resource_group.main.id
  location  = var.hostpool_location

  identity {
    type = "SystemAssigned"
  }

  body = {
    properties = {
      friendlyName          = var.hostpool_friendly_name
      description           = var.hostpool_description
      managementType        = "Automated"
      validationEnvironment = var.validate_environment
      startVMOnConnect      = var.start_vm_on_connect
      customRdpProperty     = "enablerdsaadauth:i:1;${var.custom_rdp_properties}"
      hostPoolType          = "Pooled"
      maxSessionLimit       = var.maximum_sessions_allowed
      loadBalancerType      = var.load_balancer_type
      preferredAppGroupType = var.preferred_app_group_type
    }
  }
}