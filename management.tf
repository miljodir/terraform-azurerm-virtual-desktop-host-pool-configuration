# Use azapi as this resource is still in preview and not available in terraform azurerm provider yet
moved {
  from = azapi_resource.avd_host_management
  to   = azapi_resource.avd_host_management[0]
}

resource "azapi_resource" "avd_host_management" {
  count = var.hostconfig_provisioning_enabled ? 1 : 0

  type      = "Microsoft.DesktopVirtualization/hostPools/sessionHostManagements@2025-03-01-preview"
  name      = "default"
  parent_id = azapi_resource.avd_host_pool.id

  body = {
    properties = {
      failedSessionHostCleanupPolicy = var.hostconfig_failed_session_host_cleanup_policy
      scheduledDateTimeZone          = "W. Europe Standard Time"
      provisioning = {
        instanceCount = var.hostconfig_instance_count
        setDrainMode  = var.hostconfig_set_drain_mode
        canaryPolicy  = var.hostconfig_canary_policy
      }
      update = {
        deleteOriginalVm   = var.hostconfig_delete_original_vm
        logOffDelayMinutes = var.hostconfig_logoff_delay_minutes
        logOffMessage      = var.hostconfig_logoff_message
        maxVmsRemoved      = var.hostconfig_max_vms_removed
      }
    }
  }

  depends_on = [azapi_resource.avd_host_config]
}
