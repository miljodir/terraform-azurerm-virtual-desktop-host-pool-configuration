locals {
  fslogix_enabled = var.fslogix != null
  fslogix         = local.fslogix_enabled ? { profiles = var.fslogix } : {}

  fslogix_admin_roles = {
    smb        = "Storage File Data SMB Share Elevated Contributor"
    privileged = "Storage File Data Privileged Contributor"
    reader     = "Reader"
  }
  fslogix_admin_assignments = merge({}, [
    for key, config in local.fslogix : {
      for assignment in flatten([
        for group, id in config.administrator_group_ids : [
          for role, name in local.fslogix_admin_roles : {
            key = "${group}/${role}", id = id, role = role, name = name
          }
        ]
      ]) : assignment.key => assignment
    }
  ]...)
  fslogix_profile_path          = local.fslogix_enabled ? "\\\\${var.fslogix.storage_account_name}.file.core.windows.net\\${var.fslogix.share_name}" : null
  fslogix_bootstrap_source_path = "${path.module}/scripts/Set-FSLogixHost.ps1"
  fslogix_bootstrap_unversioned = replace(
    replace(file(local.fslogix_bootstrap_source_path), "__PROFILE_PATH__", coalesce(local.fslogix_profile_path, "__PROFILE_PATH__")),
    "__HOST_PREFIX_BASE64__", base64encode(local.vm_name_prefix)
  )
  fslogix_bootstrap_version     = sha256(local.fslogix_bootstrap_unversioned)
  fslogix_bootstrap_content     = replace(local.fslogix_bootstrap_unversioned, "__CONTENT_VERSION__", local.fslogix_bootstrap_version)
}

# Deliberately independent of the host pool and its replaceable resource group.
resource "azurerm_resource_group" "fslogix" {
  for_each = { for key, config in local.fslogix : key => config if config.create_resource_group }

  name     = coalesce(each.value.resource_group_name, "${local.pool_name}-data")
  location = coalesce(each.value.location, var.location)

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [tags]
  }
}

resource "azurerm_storage_account" "fslogix" {
  for_each = local.fslogix

  name                = each.value.storage_account_name
  location            = coalesce(each.value.location, var.location)
  resource_group_name = each.value.create_resource_group ? azurerm_resource_group.fslogix[each.key].name : each.value.resource_group_name

  account_kind                    = "FileStorage"
  account_tier                    = "Premium"
  account_replication_type        = each.value.replication_type
  shared_access_key_enabled       = false
  public_network_access_enabled   = false
  allow_nested_items_to_be_public = false
  min_tls_version                 = "TLS1_2"

  azure_files_authentication {
    directory_type = "AADKERB"
  }

  share_properties {
    retention_policy {
      days = 30
    }
    smb {
      versions                        = ["SMB3.1.1"]
      authentication_types            = ["Kerberos"]
      kerberos_ticket_encryption_type = ["AES-256"]
      channel_encryption_type         = ["AES-256-GCM"]
    }
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [tags]

    precondition {
      condition     = (each.value.create_resource_group ? coalesce(each.value.resource_group_name, "${local.pool_name}-data") : each.value.resource_group_name) != local.pool_name
      error_message = "FSLogix data must not be stored in the replaceable host resource group."
    }
  }
}

resource "azurerm_storage_share" "fslogix" {
  for_each = local.fslogix

  name               = each.value.share_name
  storage_account_id = azurerm_storage_account.fslogix[each.key].id
  quota              = each.value.quota_gib
  enabled_protocol   = "SMB"

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_private_endpoint" "fslogix" {
  for_each = local.fslogix

  name                = "${local.pool_name}-profiles"
  location            = azurerm_storage_account.fslogix[each.key].location
  resource_group_name = azurerm_storage_account.fslogix[each.key].resource_group_name
  subnet_id           = each.value.private_endpoint_subnet_id

  private_service_connection {
    name                           = "profiles"
    private_connection_resource_id = azurerm_storage_account.fslogix[each.key].id
    subresource_names              = ["file"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "file"
    private_dns_zone_ids = [each.value.private_dns_zone_id]
  }
}

resource "azurerm_role_assignment" "fslogix_users" {
  for_each = local.fslogix_enabled ? var.fslogix.user_group_ids : {}

  scope                = azurerm_storage_share.fslogix["profiles"].id
  role_definition_name = "Storage File Data SMB Share Contributor"
  principal_id         = each.value
  principal_type       = "Group"
}

# Reader is explicitly required for approved portal OAuth ACL administrators.
# Privileged FileREST access bypasses ACLs; never assign this to profile users.
resource "azurerm_role_assignment" "fslogix_administrators" {
  for_each = local.fslogix_admin_assignments

  scope                = each.value.role == "smb" ? azurerm_storage_share.fslogix["profiles"].id : azurerm_storage_account.fslogix["profiles"].id
  role_definition_name = each.value.name
  principal_id         = each.value.id
  principal_type       = "Group"
}
