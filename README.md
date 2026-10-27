# Azurerm Virtual Desktop Host Pool Configuration

[![Changelog](https://img.shields.io/badge/changelog-release-green.svg)](https://github.com/miljodir/terraform-azurerm-virtual-desktop-host-pool-configuration/wiki/main#changelog)
[![TF Registry](https://img.shields.io/badge/terraform-registry-blue.svg)](https://registry.terraform.io/modules/miljodir/virtual-desktop-host-pool-configuration/azurerm/)

Creates a virtual desktop host pool, workspace and app group.
This module utilizes Azure Virtual Desktop Session host management policy to automatically create sessions hosts, instead of creating virtual machines manually.
[Note: This feature is still in preview from Microsoft.](https://learn.microsoft.com/en-us/azure/virtual-desktop/host-pool-management-approaches#session-host-configuration-management-approach)

Session hosts use [Trusted Launch](https://learn.microsoft.com/en-us/azure/virtual-machines/trusted-launch) with Secure Boot and vTPM by default. Set the `hostconfig_security_*` inputs to override this when a compatible VM size or image isn't available.

## Staged session host provisioning

Set `hostconfig_provisioning_enabled = false` for initial preparation. The module still creates the resource group, host pool with its system-assigned managed identity, workspace, access groups, and enabled role assignments, but creates neither `sessionHostConfigurations/default` nor `sessionHostManagements/default`. The `hostconfig` output is `null` in this stage. Scaling is independent of this gate: disable `enable_scaling` and `start_vm_on_connect` when preparing an isolated pilot.

Before enabling provisioning, prepare the external Key Vault secrets, verify managed identity permissions have propagated, and complete tenant, network, bootstrap, and persistent-profile storage prerequisites. Set `key_vault_id`, `kv_username_secret_id`, and `kv_password_secret_id` together to use existing credentials without generating a module-owned vault or secrets. Secret inputs are Key Vault **secret URIs**, not secret values or ARM resource IDs. With `assign_vault_permission = true`, the module grants the pool identity Key Vault Secrets User and orders configuration creation after that assignment. Resource ordering does not guarantee Azure RBAC propagation; the preparation stage is still required for externally prepared credentials.

This is an **initial preparation gate**, not a runtime pause switch. Changing it from true to false removes existing configuration and management resources. Review the plan before changing it on an existing pool. Terraform `moved` blocks migrate the previous singleton resource addresses to `[0]`, retaining existing resources with the default enabled behavior.

| Input | Default | Purpose |
| --- | --- | --- |
| `hostconfig_provisioning_enabled` | `true` | Create both configuration and management resources. |
| `hostconfig_custom_configuration_script_url` | `null` | Optional public HTTPS bootstrap script URL; null omits the ARM property. |
| `hostconfig_set_drain_mode` | `false` | Keep newly provisioned hosts drained until readiness is verified. |
| `hostconfig_delete_original_vm` | `true` | Delete originals during managed host updates; false retains deallocated originals. |
| `hostconfig_max_vms_removed` | `2` | Positive integer limiting unavailable hosts during an update. |
| `hostconfig_failed_session_host_cleanup_policy` | `KeepOne` | `KeepAll`, `KeepNone`, or `KeepOne` after failed provisioning. |
| `hostconfig_canary_policy` | `Never` | `Always`, `Auto`, or `Never` for canary provisioning. |
| `hostconfig_logoff_delay_minutes` | `10` | Integer grace period from 0 to 60 minutes. |
| `hostconfig_logoff_message` | `AVD oppdateres, du blir logget av om 10 minutter` | Sign-out message, at most 260 characters; set alongside a changed grace period. |

All previous lifecycle defaults remain unchanged. The session hosts explicitly use the module's resource group, which was also the ARM default. The dynamic Entra device group now follows the effective `vm_name_prefix`, including a supplied override; the generated prefix and default group rule are unchanged.

### Bootstrap contract

`hostconfig_custom_configuration_script_url` is passed to the existing `2025-03-01-preview` API's `customConfigurationScriptUrl`. Microsoft's [deployment prerequisites](https://learn.microsoft.com/en-us/azure/virtual-desktop/deploy-azure-virtual-desktop?pivots=host-pool-session-host-configuration) require a custom configuration **PowerShell script** URL resolvable from the public internet, and the [update guide](https://learn.microsoft.com/en-us/azure/virtual-desktop/session-host-update-configure) explicitly describes running that script during deployment. The [ARM schema](https://learn.microsoft.com/en-us/azure/templates/microsoft.desktopvirtualization/2025-03-01-preview/hostpools/sessionhostconfigurations) describes the same field as an ARM-template blob URI; this module follows the service's PowerShell guidance and passes the URL through without wrapping it or adding arguments.

Publish immutable, secret-free script content over HTTPS. The URL and script must not contain credentials: the URL is visible in the resource configuration and Terraform state. The caller owns script publishing, idempotency, failure handling, and any FSLogix or optional WSL configuration. This module does not publish scripts, configure profile storage, or verify guest readiness.

### Isolated two-host Desktop example

Use the registry source below **after a module version containing these inputs is released**, pinned to that version. Until then, a consumer PR must pin this module PR's immutable Git commit and document the release dependency rather than assuming the current registry release contains these inputs.

```hcl
module "avd_desktop" {
  source = "miljodir/virtual-desktop-host-pool-configuration/azurerm"

  name              = "dsk"
  subscription_name = "p-gis"
  subnet_id         = var.avd_subnet_id

  key_vault_id          = var.avd_key_vault_id
  kv_username_secret_id = var.avd_admin_username_secret_uri
  kv_password_secret_id = var.avd_admin_password_secret_uri

  hostconfig_provisioning_enabled              = false
  hostconfig_instance_count                    = 2
  hostconfig_set_drain_mode                    = true
  hostconfig_delete_original_vm                = false
  hostconfig_max_vms_removed                   = 1
  hostconfig_failed_session_host_cleanup_policy = "KeepAll"
  hostconfig_canary_policy                     = "Auto"
  hostconfig_logoff_delay_minutes              = 30
  hostconfig_logoff_message                    = "Desktop maintenance starts in 30 minutes. Save your work and sign out."
  hostconfig_custom_configuration_script_url   = var.avd_bootstrap_script_url
  hostconfig_image_sku                         = var.avd_image_sku
  hostconfig_image_version                     = var.avd_exact_image_version
  hostconfig_vm_size                           = "Standard_D8s_v5"

  preferred_app_group_type    = "Desktop"
  group_type                 = "Desktop"
  desktop_groups             = ["CCOE-Ekstern"]
  enable_scaling             = false
  start_vm_on_connect        = false
  assign_avd_vnet_permission  = false
  create_data_collection_rule = false
}
```

The caller supplies a supported, region-available image SKU and exact version rather than `avd-latest`/`latest`. This example creates resource group and pool `p-gis-dsk` with VM prefix `pgisdsk`; it must remain separate from any legacy pool. The legacy service-principal network assignment is disabled here; managed identity network and compute assignments remain enabled. `desktop_groups` expects existing Entra display names; the existing lookup ignores missing names, so callers should verify the exact group exists before provisioning.

After guest, Intune, profile-persistence, and application checks succeed, an operator can allow new sessions. Drain-on-provision is not a continuous guest-readiness check. Retaining originals does not prevent other resources from being destroyed or protect legacy machines in a different Terraform configuration. Never move existing legacy VMs into this pilot or delete their resources as part of adopting it.

Existing object outputs remain available: `resource_group.id`/`.name`, `hostpool.id`/`.name`, `hostpool.identity[0].principal_id`, and `desktop_group.object_id` (null when no Desktop group is created). New output `host_group.object_id`/`.display_name` exposes the dynamic Entra device group for Intune targeting.

## Validation and workflows

Pull requests run `terraform fmt -check -diff`, `terraform init -backend=false -input=false`, and `terraform validate -no-color` in GitHub Actions without Azure credentials or a deployment. Do not run plan or apply as part of module validation.

The release workflow uses the verified current major aliases: `generate-release-metadata/v1`, `create-release/v1`, and `update-wiki/v1`. These already use current action majors including checkout v7; action implementations belong to `miljodir/workflow-templates`, not this module. The validation workflow uses checkout v7 and setup-terraform v4. All GitHub Actions references use major aliases.