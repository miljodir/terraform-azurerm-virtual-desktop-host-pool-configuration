variable "storage_account_name" {}
variable "location" {}
variable "resource_group_name" {}
variable "account_kind" {}
variable "sku_name" {}
variable "allowed_copy_scope" {}
variable "sftp_enabled" {}
variable "is_hns_enabled" {}
variable "shared_access_key_enabled" {}
variable "public_network_access_enabled" {}
variable "allow_known_public_ips" {}
variable "smb_oauth_enabled" {}
variable "subnet_id" {}
variable "private_endpoints" {}
variable "private_dns_zone_ids" {}
variable "network_rules" {}
variable "azure_files_authentication" {}
variable "share_properties" {}

output "storage_account" {
  value = {
    id                  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Storage/storageAccounts/${var.storage_account_name}"
    name                = var.storage_account_name
    resource_group_name = var.resource_group_name
  }
}

output "private_endpoints" {
  value = {
    file = {
      id                         = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/privateEndpoints/pe-test"
      private_service_connection = [{ private_ip_address = "192.0.2.1" }]
    }
  }
}

output "smb_oauth_enabled" {
  value = var.smb_oauth_enabled
}
