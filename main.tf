locals {
  pool_name  = "${var.subscription_name}-${var.name}"
  short_name = replace("${var.subscription_name}${var.name}", "-", "")
  create_desktop = var.create_app_group && (var.group_type == "Desktop" || var.group_type == "Both") ? 1 : 0
  create_app     = var.create_app_group && (var.group_type == "RemoteApp" || var.group_type == "Both") ? 1 : 0
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "main" {
  name     = local.pool_name
  location = var.location
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azuread_group" "avd_host_group" {
  display_name     = "${var.entra_id_host_group_prefix} - ${local.pool_name}"
  description      = "Dynamic group for host in host pool ${local.pool_name}. Used in Intune assignments."
  security_enabled = true
  types            = ["DynamicMembership"]

  dynamic_membership {
    enabled = true
    rule    = "(device.displayName -startsWith \"${local.short_name}\") and (device.deviceOSType -eq \"Windows\")"
  }
}

# This might be removed in the future is Host Configuration can rely on managed identity only
resource "azurerm_role_assignment" "avd_network_contributor" {
  count                = var.assign_avd_vnet_permission ? 1 : 0
  scope                = join("", slice(split("/subnets", var.subnet_id), 0, 1)) # extract vnet id from subnet id
  role_definition_name = "Network Contributor"
  principal_id         = "7b438d0e-4915-4fe9-b343-6837baf39748" #Azure Virtual Desktop app
  principal_type       = "ServicePrincipal"
}