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
  value = local.create_desktop == 1 ? azuread_group.desktop_users[0] : null
}

output "app_group" {
  value = local.create_app == 1 ? azuread_group.app_users[0] : null
}


locals {
  avd_username = "MYUSERNAME@miljodir.no"
}

data "azapi_resource" "desktop" {
  count = local.create_desktop == 1 ? 1 : 0

  type      = "Microsoft.DesktopVirtualization/applicationGroups/desktops@2024-04-03"
  name      = "SessionDesktop"
  parent_id = azurerm_virtual_desktop_application_group.desktop[0].id

  response_export_values = {
    arm_id    = "id"
    object_id = "properties.objectId"
  }
}

data "azapi_resource_list" "apps" {
  count = local.create_app == 1 ? 1 : 0

  type      = "Microsoft.DesktopVirtualization/applicationGroups/applications@2024-04-03"
  parent_id = azurerm_virtual_desktop_application_group.app[0].id

  response_export_values = {
    value = "value[].{name:name,id:id,object_id:properties.objectId}"
  }
}

locals {
  desktop_object_id = local.create_desktop == 1 ? data.azapi_resource.desktop[0].output.object_id : null

  desktop_connection_uri = local.desktop_object_id != null ? (
    "ms-avd:connect?resourceid=${
      urlencode(local.desktop_object_id)
    }&username=${local.avd_username}"
  ) : null

  remoteapps = local.create_app == 1 ? {
    for app in data.azapi_resource_list.apps[0].output.value :
    app.name => {
      uri       = "ms-avd:connect?resourceid=${urlencode(app.object_id)}&username=${local.avd_username}"
    }
  } : {}
}

output "desktop_object_id" {
  description = "AVD desktop objectId used by ms-avd:connect deep links."
  value       = local.desktop_object_id
}

output "desktop_connection_uri" {
  description = "Workaround to connect directly to the Desktop using its AVD objectId. See https://learn.microsoft.com/en-us/azure/virtual-desktop/preferred-application-group-type#expected-behavior for details"
  value       = local.desktop_connection_uri
}

output "remoteapps" {
  description = "Workaround to connect directly to the RemoteApps using their AVD objectIds. See https://learn.microsoft.com/en-us/azure/virtual-desktop/preferred-application-group-type#expected-behavior for details"
  value       = local.remoteapps
}
