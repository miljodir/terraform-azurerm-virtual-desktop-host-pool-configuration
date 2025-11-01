data "azurerm_subscription" "current" {}

data "azapi_resource_list" "image_offer_skus" {
  type      = "Microsoft.Compute/locations/publishers/artifacttypes/offers/skus@2025-04-01"
  parent_id = "/Subscriptions/${local.subscription}/Providers/Microsoft.Compute/Locations/${var.hostconfig_image_publisher_location}/Publishers/${var.hostconfig_image_publisher}/ArtifactTypes/VMImage/Offers/${var.hostconfig_image_offer}"
  response_export_values = { "names": "[].name" }
  depends_on = [ data.azurerm_subscription.current ]
}

data "azapi_resource_list" "image_offer_sku_versions" {
  type      = "Microsoft.Compute/locations/publishers/artifacttypes/offers/skus/versions@2025-04-01"
  parent_id = "/Subscriptions/${local.subscription}/Providers/Microsoft.Compute/Locations/${var.hostconfig_image_publisher_location}/Publishers/${var.hostconfig_image_publisher}/ArtifactTypes/VMImage/Offers/${var.hostconfig_image_offer}/Skus/${local.use_avd_sku}"
  response_export_values = { "names": "[].name" }

  depends_on = [ data.azapi_resource_list.image_offer_skus ]
}

locals {
  subscription = data.azurerm_subscription.current.subscription_id

  sku_names = data.azapi_resource_list.image_offer_skus.output.names
  avd_sku_names = [for name in local.sku_names : name if endswith(name, "-avd")]
  # select last in avd_sku_names
  latest_avd_sku = length(local.avd_sku_names) > 0 ? local.avd_sku_names[length(local.avd_sku_names) - 1] : null
  use_avd_sku = var.hostconfig_image_sku != "avd-latest" ? var.hostconfig_image_sku : local.latest_avd_sku

  avd_sku_version_names = data.azapi_resource_list.image_offer_sku_versions.output.names
  latest_avd_sku_version = length(local.avd_sku_version_names) > 0 ? local.avd_sku_version_names[length(local.avd_sku_version_names) - 1] : null
  use_avd_sku_version = var.hostconfig_image_version != "latest" ? var.hostconfig_image_version : local.latest_avd_sku_version
}