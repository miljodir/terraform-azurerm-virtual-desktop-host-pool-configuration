# Use azapi as this resource is still in preview and not available in terraform azurerm provider yet
resource "azapi_resource" "avd_host_management" {
  type      = "Microsoft.DesktopVirtualization/hostPools/sessionHostManagements@2025-03-01-preview"
  name      = "default"
  parent_id = azapi_resource.avd_host_pool.id

  body = {
    properties = {
      failedSessionHostCleanupPolicy = "KeepOne"
      scheduledDateTimeZone          = "W. Europe Standard Time"
      provisioning = {
        instanceCount = var.hostconfig_instance_count
        setDrainMode  = false
        canaryPolicy  = "Never"
      }
      update = {
        deleteOriginalVm   = true
        logOffDelayMinutes = 10
        logOffMessage      = "AVD oppdateres, du blir logget av om 10 minutter"
        maxVmsRemoved      = 2
      }
    }
  }
}
