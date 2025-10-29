locals {
  pool_name  = "${var.subscription_name}-${var.name}"
  short_name = replace("${var.subscription_name}${var.name}", "-", "")
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