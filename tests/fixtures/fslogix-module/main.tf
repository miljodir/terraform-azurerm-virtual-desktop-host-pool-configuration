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
variable "subnet_id" {}
variable "private_endpoints" {}
variable "private_dns_zone_ids" {}
variable "network_rules" {}
variable "azure_files_authentication" {}
variable "share_properties" {}

output "storage_account" {
  value = {}
}

output "private_endpoints" {
  value = {}
}
