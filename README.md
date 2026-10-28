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

Publish immutable, secret-free script content over HTTPS. The URL and script must not contain credentials: the URL is visible in the resource configuration and Terraform state. The caller owns publishing and guest readiness. Optional FSLogix storage and canonical host configuration are available below; WSL and application packaging remain workload-owned.

## Optional cloud-only FSLogix

`fslogix = null` (default) creates **no** profile resources and returns null for both new outputs. Existing inputs, defaults, resource addresses, vault behavior and host configuration are unchanged. The feature adds resources only in `fslogix.tf`; it does not attach extensions, enable provisioning, change the bootstrap URL, or modify tenant configuration. Enabling storage alone does **not** make a host ready.

```hcl
# Add to the existing host-pool module block, not a second pool:
fslogix = {
  storage_account_name       = "pgisdskprofiles" # Explicit name, no generated suffix.
  create_resource_group      = false
  resource_group_name        = azurerm_resource_group.desktop_data.name
  location                   = azurerm_resource_group.desktop_data.location
  private_endpoint_subnet_id = var.private_endpoint_subnet_id
  user_group_ids             = { desktop = var.desktop_users_object_id }
  administrator_group_ids    = { approved = var.profile_administrators_object_id }
  replication_type           = "ZRS"
}
```

### Input contract

One nullable typed object, `fslogix`:

| Attribute | Type / default | Contract |
| --- | --- | --- |
| `storage_account_name` | required string | Globally unique 3–24 lowercase alphanumeric account name. |
| `private_endpoint_subnet_id` | required string | Existing private endpoint subnet ARM ID. |
| `private_dns_zone_id` | string / null | Optional existing `privatelink.file.core.windows.net` zone ARM ID for an explicit DNS-zone group. Leave null when Azure Policy manages private-endpoint DNS. |
| `user_group_ids` | required map(string) | Stable caller keys → cloud-only desktop user Entra group object IDs. |
| `administrator_group_ids` | required map(string) | Stable caller keys → approved profile administrator group object IDs. |
| `create_resource_group` | bool / `true` | False uses a caller-owned existing data RG without managing its lifecycle. |
| `resource_group_name` | string / null | Defaults to `<pool_name>-data` when creating; required for existing RG mode. Never use the host RG. |
| `location` | string / null | Defaults to module `location`; match the existing data RG when using one. |
| `replication_type` | string / `ZRS` | Premium ZRS; LRS allowed for dev/test or regional availability. |
| `share_name` | string / `profiles` | SMB share name. |
| `quota_gib` | number / `100` | Integer 100–102400 GiB. |

Map **keys** and feature enablement must be plan-known; group IDs can be provider-computed. Keep admin groups distinct from user groups. Only `Group` principals are assigned. Users receive share-scoped **Storage File Data SMB Share Contributor**. Administrators receive share-scoped **Storage File Data SMB Share Elevated Contributor**, account-scoped **Storage File Data Privileged Contributor**, and account-scoped **Reader** (explicitly needed for portal administration). Privileged OAuth access bypasses file ACLs: restrict it to approved administrators; this dedicated account should contain only profile data.

The account is private-only Premium FileStorage with keys disabled, AADKERB, TLS 1.2 minimum, SMB 3.1.1, Kerberos-only authentication, AES-256 tickets/channel encryption, and 30-day share soft-delete retention. No default share permission is granted. A File private endpoint is created in the data RG. Register `Microsoft.Storage` and `Microsoft.Network` in the caller's provider setup. This feature adds no passwords, tenant writes, diagnostic settings or tags.

The account and File private endpoint are created by `miljodir/storage-account/azurerm` with `version = "~> 1.12"`. The existing `fslogix.private_endpoint_subnet_id` is passed to its `subnet_id` input. This is the private endpoint subnet, not a public storage service-endpoint allow rule. By default no DNS-zone mapping is passed: Azure Policy manages private-endpoint DNS. Only set `private_dns_zone_id` when an explicit module-created File DNS-zone group is needed outside that policy setup. The shared module ignores DNS-zone-group changes, preserving policy-managed or existing groups; verify private DNS resolution and policy remediation before using the share.

The account explicitly uses `allowed_copy_scope = "AAD"` and network ACLs with `default_action = "Deny"`, `bypass = ["None"]`, and empty IP/subnet allow lists. SFTP and HNS remain disabled, so the shared module disables local storage users. `allow_known_public_ips = false` prevents its development-environment convenience behavior from enabling public access or public IP exceptions. Disabling public network access alone does not satisfy policies that inspect `networkAcls`. The [copy-scope restriction](https://learn.microsoft.com/en-us/azure/storage/common/security-restrict-copy-operations) also applies to Azure Files copy APIs; cross-account copy sources must belong to the same Entra tenant.

**Storage-module version:** release `1.12.0` of the storage module ([miljodir/terraform-azurerm-storage-account#29](https://github.com/miljodir/terraform-azurerm-storage-account/pull/29)) is the minimum: it exposes the required `share_properties`, `private_dns_zone_ids`, and `allow_known_public_ips` inputs and keeps the requested Premium replication (for example `Premium_ZRS`). Earlier releases such as `1.11.1` lack these inputs and force Premium replication to LRS; do not pin them or temporarily enable public access as a workaround. Terraform 1.7 or newer is required by the shared module's existing `removed` block.

The module-owned data RG and share retain `prevent_destroy`; the shared-module account has no `prevent_destroy` or Azure lock. None depends on the host pool or host RG. Caller-owned RG/vault protection remains the caller's responsibility. Keep account/RG/share identity stable across host replacement and review all deletion/replacement plans. `prevent_destroy` is a Terraform configuration guard, **not** an Azure lock or backup: removing the entire module/resource declarations removes that protection. Never remove state/configuration or delete the data RG as a host replacement procedure.

State-migration blocks move the former `azurerm_storage_account.fslogix["profiles"]` and `azurerm_private_endpoint.fslogix["profiles"]` into the shared module without changing their Azure IDs. The shared module ignores endpoint/connection-name changes, retaining the existing endpoint names during migration; newly created endpoints use its naming convention. Review the consumer's GitHub Actions plan to confirm moves rather than replacements. The output shape and all existing FSLogix inputs remain unchanged.

### Outputs and canonical bootstrap consumption

`fslogix` returns `resource_group_name`, `storage_account_id`, `storage_account_name`, `share_id` (ARM scope), `share_name`, `profile_path` (UNC), `private_endpoint_id`, and `private_ip_address`.

`fslogix_bootstrap` returns:

- `source_path`: module-local `scripts/Set-FSLogixHost.ps1` template, **not** a published URL or a portable path.
- `relative_path`: `scripts/Set-FSLogixHost.ps1`, for build runners acquiring the module repository at an immutable commit.
- `source_sha256`: SHA-256 of the raw canonical template.
- `content`: fully rendered PowerShell containing the profile UNC and base64-encoded effective `vm_name_prefix`. No additional token replacement or command-line arguments are needed.
- `version`: SHA-256 of the configured script before substituting its version marker (avoids a self-referential hash).
- `content_sha256`: SHA-256 of the final UTF-8 content; use this for artifact integrity.
- `file_name`: `Set-FSLogixHost-<version>.ps1`, suitable for immutable publication.

**Packaging before infrastructure apply, without Terraform init:** acquire this repository at the immutable implementation commit pinned by the consumer, read `scripts/Set-FSLogixHost.ps1`, and verify its raw SHA-256 against the reviewed template hash. Use LF checkout bytes (disable Git autocrlf) for stable hashes. Replace `__PROFILE_PATH__` with the validated profile UNC and `__HOST_PREFIX_BASE64__` with UTF-8 base64 of the effective host prefix (for example `pgisdsk`). Hash the resulting UTF-8 script with LF line endings and no BOM to get the content version, then replace `__CONTENT_VERSION__` with that hash. Fail if any template markers remain. Publish/package only the rendered artifact. Pinning the repository commit and template hash needs no Terraform outputs; no local duplicate is needed. The version marker and controlled-restart markers retain the workload contract.

Alternatively expose these outputs from the caller root to its packaging/publishing process. Write `content` as UTF-8 without changing bytes/newlines; do not copy/fork the canonical template or reconstruct its settings in the workload. For example, root outputs:

```hcl
output "desktop_fslogix" {
  description = "Profile storage contract for packaging and readiness."
  value       = module.avd_desktop.fslogix
}

output "desktop_fslogix_bootstrap" {
  description = "Rendered immutable host script for the workload publisher."
  value       = module.avd_desktop.fslogix_bootstrap
}
```

The workload publisher should package this rendered content as its host install script (instead of reading/replacing the former workload `Set-DesktopHost.ps1`), using `version` for detection. Alternatively, publish it under `file_name` at an immutable secret-free public HTTPS URL and pass that URL to `hostconfig_custom_configuration_script_url` in a **later preparation stage**. Do not construct an intra-module cyclic dependency on a published artifact requiring the module's completed outputs. Keep `hostconfig_provisioning_enabled = false` until publication and all prerequisites are complete. No Intune publisher or tenant-wide workflow is moved into this module.

The bootstrap enforces the effective host name prefix, requires preinstalled supported FSLogix, requires running `WinHttpAutoProxySvc` and `iphlpsvc` (fails if disabled), configures dynamic **30 GiB VHDX**, `RoamIdentity=0`, exclusive profile use, no deletion of existing local profiles, and fail-closed login/no temporary fallback. It enables cloud Kerberos ticket retrieval and credential loading; it does not configure storage keys or machine-account mounting. Markers stay in `C:\ProgramData\Miljodir\AvdDesktop` for existing readiness tooling: `bootstrap-version.txt` and `restart-required.txt`. It never reboots automatically or clears the restart marker. Keep hosts drained; readiness must prove `LastBootUpTime` is later than the marker after a controlled reboot. WSL directory setup from the old workload script is intentionally **not** included; retain it with workload-owned WSL packaging if needed.

### Explicit prerequisites and acceptance

- Validate current Microsoft cloud-only Entra Kerberos/FSLogix support, OS release-specific updates, FSLogix version, Entra join/PRT, required services, network TCP 445 and private-only DNS resolution for the actual image. AADKERB on the account is not proof of working cloud-only authentication.
- A tenant administrator must review/configure required storage application consent and Conditional Access exclusions using supported procedures. This module does not grant consent, change CA, or make unverified tenant writes.
- Approved administrators must initialize/review root and per-user profile ACL inheritance using Azure portal **Manage access** with OAuth from a network that can reach the private endpoint. User share RBAC is not file ACL isolation. Do **not** claim `icacls` or SMB File Explorer ACL administration for cloud-only identities. No unverified OAuth REST ACL writer is provided.
- Test two separate cloud-only users: each can create/use their own profile and cannot read or change the other's profile. Separately prove sequential reuse of the **same VHDX** after host replacement, with sign-out/detach before the next mount; never concurrent read/write mounts. These tests are required even when running one host.
- Inspect FSLogix logs/container attachment and absence of local/temporary-profile fallback. Preserve data independently of host lifecycle. Neither Terraform validation nor the bootstrap marker proves a live FSLogix profile, ACL isolation or replacement persistence.

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

The workflow also checks the FSLogix shared-module input contract for the five reported storage-policy denials (copy scope, disabled local-user prerequisites, bypass, default deny, and no IP allow rules), private subnet/DNS forwarding, state moves, Premium FileStorage, and AADKERB. These are configuration regressions, not live Azure Policy evaluation or proof of service acceptance. Initialization also requires authorized access to the shared storage module's internal `cp-shared` dependency, even for private-only accounts; the workflow loads the organization `ACCESS_SHARED_CONFIGURATION` SSH key for this (unavailable to fork pull requests). Publish an immutable host-pool module release before updating a consumer pin; an older pinned revision does not acquire these settings.

The release workflow uses the verified current major aliases: `generate-release-metadata/v1`, `create-release/v1`, and `update-wiki/v1`. These already use current action majors including checkout v7; action implementations belong to `miljodir/workflow-templates`, not this module. The validation workflow uses checkout v7 and setup-terraform v4. All GitHub Actions references use major aliases.