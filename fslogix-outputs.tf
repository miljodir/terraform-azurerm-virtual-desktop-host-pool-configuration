output "fslogix" {
  description = "Persistent profile storage contract, or null when disabled. Resource IDs use ARM scopes; profile_path is the SMB UNC."
  value = local.fslogix_enabled ? {
    resource_group_name  = module.fslogix["profiles"].storage_account.resource_group_name
    storage_account_id   = module.fslogix["profiles"].storage_account.id
    storage_account_name = module.fslogix["profiles"].storage_account.name
    share_id             = azurerm_storage_share.fslogix["profiles"].id
    share_name           = azurerm_storage_share.fslogix["profiles"].name
    profile_path         = local.fslogix_profile_path
    private_endpoint_id  = module.fslogix["profiles"].private_endpoints["file"].id
    private_ip_address   = module.fslogix["profiles"].private_endpoints["file"].private_service_connection[0].private_ip_address
  } : null
}

output "fslogix_bootstrap" {
  description = "Canonical template path plus fully rendered secret-free PowerShell and deterministic version/content hashes, or null when disabled. Publish content, not the unrendered source_path."
  value = local.fslogix_enabled ? {
    source_path    = local.fslogix_bootstrap_source_path
    relative_path  = "scripts/Set-FSLogixHost.ps1"
    source_sha256  = filesha256(local.fslogix_bootstrap_source_path)
    content        = local.fslogix_bootstrap_content
    version        = local.fslogix_bootstrap_version
    content_sha256 = sha256(local.fslogix_bootstrap_content)
    file_name      = "Set-FSLogixHost-${local.fslogix_bootstrap_version}.ps1"
  } : null
}
