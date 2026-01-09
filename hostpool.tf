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

resource "azurerm_monitor_data_collection_rule" "avd_insights" {
  count               = var.create_data_collection_rule ? 1 : 0
  location            = var.hostpool_location
  name                = "microsoft-avdi-${var.hostpool_location}-${local.pool_name}"
  resource_group_name = azurerm_resource_group.main.id
  data_flow {
      destinations = [
          "CentralLogAnalyticsWorkspace",
        ]
      streams      = [
          "Microsoft-Perf",
          "Microsoft-Event",
        ]
    }

  destinations {
      log_analytics {
        name                  = "CentralLogAnalyticsWorkspace"
        workspace_resource_id = var.log_analytics_workspace_id
      }
    }
  }