mock_provider "azurerm" {
  mock_data "azurerm_subscription" {
    defaults = {
      subscription_id = "00000000-0000-0000-0000-000000000000"
    }
  }

  mock_data "azurerm_client_config" {
    defaults = {
      tenant_id = "00000000-0000-0000-0000-000000000000"
    }
  }

  # Generated mock IDs are random strings; resources that parse IDs need real-looking ones.
  mock_resource "azurerm_resource_group" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/t-test-dsk"
    }
  }

  mock_resource "azurerm_key_vault" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/t-test-dsk/providers/Microsoft.KeyVault/vaults/t-test-dsk-kv"
    }
  }

  mock_resource "azurerm_key_vault_secret" {
    defaults = {
      id = "https://t-test-dsk-kv.vault.azure.net/secrets/secret/00000000000000000000000000000000"
    }
  }

  mock_resource "azurerm_storage_share" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/t-test-dsk-data/providers/Microsoft.Storage/storageAccounts/ttestdskprofiles/fileServices/default/shares/profiles"
    }
  }

  mock_resource "azurerm_virtual_desktop_workspace" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/t-test-dsk/providers/Microsoft.DesktopVirtualization/workspaces/t-test-dsk"
    }
  }

  mock_resource "azurerm_virtual_desktop_application_group" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/t-test-dsk/providers/Microsoft.DesktopVirtualization/applicationGroups/t-test-dsk-desktop"
    }
  }
}

mock_provider "azapi" {}
mock_provider "azuread" {}
mock_provider "random" {}

variables {
  name              = "dsk"
  subscription_name = "t-test"
  subnet_id         = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/snet-hosts"
  # The default data collection rule needs a workspace.
  log_analytics_workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-logs/providers/Microsoft.OperationalInsights/workspaces/log-test"
}

# Marketplace image lookups are data sources; return fixed SKU and version lists.
override_data {
  target = data.azapi_resource_list.image_offer_skus
  values = {
    output = {
      names = ["win11-23h2-avd", "win11-24h2-avd", "win11-24h2-ent"]
    }
  }
}

override_data {
  target = data.azapi_resource_list.image_offer_sku_versions
  values = {
    output = {
      names = ["26100.1000.240101", "26100.2000.240201"]
    }
  }
}

override_data {
  target = data.azapi_resource_list.desktops[0]
  values = {
    output = {
      value = [{ name = "SessionDesktop", object_id = "00000000-0000-0000-0000-000000000099" }]
    }
  }
}

override_resource {
  target = azapi_resource.avd_host_pool
  values = {
    id       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/t-test-dsk/providers/Microsoft.DesktopVirtualization/hostPools/t-test-dsk"
    identity = { principal_id = "00000000-0000-0000-0000-000000000010" }
  }
}

run "defaults" {
  command = apply

  assert {
    condition     = azurerm_resource_group.main.name == "t-test-dsk"
    error_message = "Resource group should be named '<subscription>-<name>'."
  }

  assert {
    condition     = azapi_resource.avd_host_pool.name == "t-test-dsk"
    error_message = "Host pool should be named '<subscription>-<name>'."
  }

  assert {
    condition     = azapi_resource.avd_host_pool.body.properties.managementType == "Automated"
    error_message = "Host pool should use automated session host management."
  }

  assert {
    condition     = startswith(azapi_resource.avd_host_pool.body.properties.customRdpProperty, "enablerdsaadauth:i:1;")
    error_message = "Entra ID RDP authentication should always be enabled."
  }

  assert {
    condition     = local.use_avd_sku == "win11-24h2-avd"
    error_message = "The latest '-avd' image SKU should be selected."
  }

  assert {
    condition     = local.use_avd_sku_version == "26100.2000.240201"
    error_message = "The latest image version should be selected."
  }

  assert {
    condition     = azapi_resource.avd_host_config[0].body.properties.vmNamePrefix == "ttestdsk"
    error_message = "VM name prefix should default to subscription and name without dashes."
  }

  assert {
    condition     = !contains(keys(azapi_resource.avd_host_config[0].body.properties), "customConfigurationScriptUrl")
    error_message = "customConfigurationScriptUrl should be omitted by default."
  }

  assert {
    condition     = length(azurerm_key_vault.main) == 1 && length(random_password.main) == 1
    error_message = "A key vault with generated admin credentials should be created by default."
  }

  assert {
    condition     = azapi_resource.avd_host_config[0].body.properties.vmAdminCredentials.passwordKeyVaultSecretUri == azurerm_key_vault_secret.host_pool_admin_password[0].id
    error_message = "Host configuration should use the generated password secret."
  }

  assert {
    condition     = azuread_group.avd_host_group.dynamic_membership[0].rule == "(device.displayName -startsWith \"ttestdsk\") and (device.deviceOSType -eq \"Windows\")"
    error_message = "Host device group should match VMs by name prefix."
  }

  assert {
    condition     = azurerm_role_assignment.avd_network_contributor[0].scope == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet-test"
    error_message = "VNet permissions should be scoped to the VNet extracted from subnet_id."
  }

  assert {
    condition     = length(azurerm_virtual_desktop_application_group.desktop) == 1 && length(azurerm_virtual_desktop_application_group.app) == 0
    error_message = "Only a desktop application group should be created by default."
  }

  assert {
    condition     = azurerm_virtual_desktop_application_group.desktop[0].name == "t-test-dsk-desktop"
    error_message = "Desktop application group should be named '<host pool>-desktop'."
  }

  assert {
    condition     = output.desktop_connection_uri["SessionDesktop"] == "ms-avd:connect?resourceid=00000000-0000-0000-0000-000000000099&username=${local.avd_username}"
    error_message = "Desktop connection URIs should be built from the desktop object IDs."
  }

  assert {
    condition     = toset([for s in azurerm_virtual_desktop_scaling_plan.main.schedule : s.name]) == toset(["Weekdays", "Sunday-patch"])
    error_message = "Default scaling schedules should be created."
  }

  assert {
    condition     = alltrue([for s in azurerm_virtual_desktop_scaling_plan.main.schedule : s.peak_load_balancing_algorithm == "DepthFirst"])
    error_message = "Scaling schedules should inherit the host pool load balancer type."
  }

  assert {
    condition     = output.fslogix == null && output.fslogix_bootstrap == null && length(module.fslogix) == 0
    error_message = "FSLogix should be disabled by default."
  }
}

run "remote_apps_and_existing_key_vault" {
  command = apply

  variables {
    group_type            = "Both"
    vm_name_prefix        = "avdtest"
    key_vault_id          = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-kv/providers/Microsoft.KeyVault/vaults/kv-test"
    kv_username_secret_id = "https://kv-test.vault.azure.net/secrets/username"
    kv_password_secret_id = "https://kv-test.vault.azure.net/secrets/password"
    applications = {
      notepad = {
        path = "C:\\Windows\\System32\\notepad.exe"
      }
    }
  }

  assert {
    condition     = length(azurerm_key_vault.main) == 0 && length(random_password.main) == 0
    error_message = "No key vault should be created when key_vault_id is set."
  }

  assert {
    condition     = azurerm_role_assignment.pool_vault_secrets_user[0].scope == var.key_vault_id
    error_message = "The host pool should be granted access to the existing key vault."
  }

  assert {
    condition     = azapi_resource.avd_host_config[0].body.properties.vmAdminCredentials.usernameKeyVaultSecretUri == "https://kv-test.vault.azure.net/secrets/username"
    error_message = "Existing username secret should be used."
  }

  assert {
    condition     = azapi_resource.avd_host_config[0].body.properties.vmNamePrefix == "avdtest"
    error_message = "vm_name_prefix should override the generated prefix."
  }

  assert {
    condition     = length(azurerm_virtual_desktop_application_group.desktop) == 1 && length(azurerm_virtual_desktop_application_group.app) == 1
    error_message = "Both desktop and RemoteApp groups should be created."
  }

  assert {
    condition     = azurerm_virtual_desktop_application.apps["notepad"].command_line_argument_policy == "DoNotAllow"
    error_message = "Applications should not allow command line arguments by default."
  }
}

run "preparation_without_provisioning" {
  command = apply

  variables {
    hostconfig_provisioning_enabled = false
    create_app_group                = false
    create_data_collection_rule     = false
    assign_vnet_permission          = false
    assign_avd_vnet_permission      = false
  }

  assert {
    condition     = length(azapi_resource.avd_host_config) == 0 && length(azapi_resource.avd_host_management) == 0
    error_message = "No session host configuration should be created when provisioning is disabled."
  }

  assert {
    condition     = output.hostconfig == null
    error_message = "hostconfig output should be null when provisioning is disabled."
  }

  assert {
    condition     = length(azurerm_virtual_desktop_application_group.desktop) == 0 && output.desktop_group == null
    error_message = "No application groups should be created when create_app_group = false."
  }

  assert {
    condition     = length(azurerm_monitor_data_collection_rule.avd_insights) == 0
    error_message = "The data collection rule should be optional."
  }

  assert {
    condition     = length(azurerm_role_assignment.pool_network_contributor) == 0 && length(azurerm_role_assignment.avd_network_contributor) == 0
    error_message = "VNet permissions should be optional."
  }
}

run "explicit_image_and_script" {
  command = plan

  variables {
    hostconfig_image_sku                       = "win11-23h2-avd"
    hostconfig_image_version                   = "22631.1000.230101"
    hostconfig_custom_configuration_script_url = "https://example.com/scripts/configure.ps1"
  }

  assert {
    condition     = azapi_resource.avd_host_config[0].body.properties.imageInfo.marketplaceInfo.sku == "win11-23h2-avd"
    error_message = "An explicit image SKU should be used as-is."
  }

  assert {
    condition     = azapi_resource.avd_host_config[0].body.properties.imageInfo.marketplaceInfo.exactVersion == "22631.1000.230101"
    error_message = "An explicit image version should be used as-is."
  }

  assert {
    condition     = azapi_resource.avd_host_config[0].body.properties.customConfigurationScriptUrl == "https://example.com/scripts/configure.ps1"
    error_message = "customConfigurationScriptUrl should be passed through."
  }
}

# FSLogix resources use prevent_destroy, so these runs stay in plan mode.
run "fslogix_defaults" {
  command = plan

  variables {
    fslogix = {
      storage_account_name       = "ttestdskprofiles"
      private_endpoint_subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/snet-pe"
      user_group_ids             = { users = "00000000-0000-0000-0000-000000000001" }
      administrator_group_ids    = { admins = "00000000-0000-0000-0000-000000000002" }
    }
  }

  override_module {
    target = module.fslogix
    outputs = {
      storage_account = {
        id                  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/t-test-dsk-data/providers/Microsoft.Storage/storageAccounts/ttestdskprofiles"
        name                = "ttestdskprofiles"
        resource_group_name = "t-test-dsk-data"
      }
      private_endpoints = {
        file = {
          id                         = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/t-test-dsk-data/providers/Microsoft.Network/privateEndpoints/pe-file"
          private_service_connection = [{ private_ip_address = "10.0.0.5" }]
        }
      }
    }
  }

  assert {
    condition     = azurerm_resource_group.fslogix["profiles"].name == "t-test-dsk-data"
    error_message = "FSLogix data should get its own '<host pool>-data' resource group by default."
  }

  assert {
    condition     = azurerm_storage_share.fslogix["profiles"].name == "profiles" && azurerm_storage_share.fslogix["profiles"].quota == 100
    error_message = "The profile share should default to 'profiles' with a 100 GiB quota."
  }

  assert {
    condition     = local.fslogix_profile_path == "\\\\ttestdskprofiles.file.core.windows.net\\profiles"
    error_message = "Profile path should be the SMB UNC path of the share."
  }

  assert {
    condition     = length(regexall("__PROFILE_PATH__|__HOST_PREFIX_BASE64__|__CONTENT_VERSION__", local.fslogix_bootstrap_content)) == 0
    error_message = "All placeholders in the bootstrap script should be rendered."
  }

  assert {
    condition     = length(local.fslogix_admin_assignments) == 3
    error_message = "Each administrator group should get SMB elevated, privileged and reader roles."
  }

  assert {
    condition     = azurerm_role_assignment.fslogix_users["users"].role_definition_name == "Storage File Data SMB Share Contributor"
    error_message = "Profile users should get SMB share contributor on the share."
  }
}

run "fslogix_must_not_use_host_resource_group" {
  command = plan

  variables {
    fslogix = {
      storage_account_name       = "ttestdskprofiles"
      private_endpoint_subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/snet-pe"
      user_group_ids             = { users = "00000000-0000-0000-0000-000000000001" }
      administrator_group_ids    = { admins = "00000000-0000-0000-0000-000000000002" }
      create_resource_group      = false
      resource_group_name        = "t-test-dsk"
    }
  }

  override_module {
    target = module.fslogix
    outputs = {
      storage_account = {
        id                  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/t-test-dsk/providers/Microsoft.Storage/storageAccounts/ttestdskprofiles"
        name                = "ttestdskprofiles"
        resource_group_name = "t-test-dsk"
      }
      private_endpoints = {
        file = {
          id                         = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/t-test-dsk-data/providers/Microsoft.Network/privateEndpoints/pe-file"
          private_service_connection = [{ private_ip_address = "10.0.0.5" }]
        }
      }
    }
  }

  expect_failures = [azurerm_storage_share.fslogix["profiles"]]
}

run "fslogix_rejects_group_names" {
  command = plan

  variables {
    fslogix = {
      storage_account_name       = "ttestdskprofiles"
      private_endpoint_subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/snet-pe"
      user_group_ids             = { users = "Example Users" }
      administrator_group_ids    = { admins = "00000000-0000-0000-0000-000000000002" }
    }
  }

  expect_failures = [var.fslogix]
}

run "invalid_name_length" {
  command = plan

  variables {
    name = "toolong"
  }

  expect_failures = [var.name]
}

run "invalid_group_type" {
  command = plan

  variables {
    group_type = "Desktops"
  }

  expect_failures = [var.group_type]
}

run "invalid_script_url" {
  command = plan

  variables {
    hostconfig_custom_configuration_script_url = "http://example.com/configure.ps1"
  }

  expect_failures = [var.hostconfig_custom_configuration_script_url]
}
