resource "azurerm_virtual_desktop_workspace" "main" {
  name                = azurerm_resource_group.main.name
  resource_group_name = azurerm_resource_group.main.name
  location            = var.hostpool_location
  friendly_name       = var.workspace_friendly_name
  description         = var.workspace_description
}