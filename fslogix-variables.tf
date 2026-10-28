variable "fslogix" {
  description = "Optional private cloud-only Entra FSLogix storage and rendered host bootstrap. Null leaves all existing module behavior unchanged. Group maps use stable caller-chosen keys and Entra object IDs as values."
  type = object({
    storage_account_name       = string
    private_endpoint_subnet_id = string
    private_dns_zone_id        = optional(string)
    user_group_ids             = map(string)
    administrator_group_ids    = map(string)
    create_resource_group      = optional(bool, true)
    resource_group_name        = optional(string)
    location                   = optional(string)
    replication_type           = optional(string, "ZRS")
    share_name                 = optional(string, "profiles")
    quota_gib                  = optional(number, 100)
    smb_security_profile       = optional(string, "maximum_security")
    smb_settings = optional(object({
      versions                        = list(string)
      authentication_types            = list(string)
      kerberos_ticket_encryption_type = list(string)
      channel_encryption_type         = list(string)
    }))
  })
  default = null

  validation {
    condition     = var.fslogix == null ? true : contains(["maximum_security", "maximum_compatibility"], var.fslogix.smb_security_profile)
    error_message = "smb_security_profile must be maximum_security or maximum_compatibility."
  }

  validation {
    condition = try(var.fslogix.smb_settings, null) == null ? true : (
      length(var.fslogix.smb_settings.versions) > 0 &&
      length(var.fslogix.smb_settings.authentication_types) > 0 &&
      length(var.fslogix.smb_settings.kerberos_ticket_encryption_type) > 0 &&
      length(var.fslogix.smb_settings.channel_encryption_type) > 0 &&
      alltrue([for v in var.fslogix.smb_settings.versions : contains(["SMB2.1", "SMB3.0", "SMB3.1.1"], v)]) &&
      alltrue([for v in var.fslogix.smb_settings.authentication_types : contains(["NTLMv2", "Kerberos"], v)]) &&
      alltrue([for v in var.fslogix.smb_settings.kerberos_ticket_encryption_type : contains(["RC4-HMAC", "AES-256"], v)]) &&
      alltrue([for v in var.fslogix.smb_settings.channel_encryption_type : contains(["AES-128-CCM", "AES-128-GCM", "AES-256-GCM"], v)])
    )
    error_message = "smb_settings lists must be nonempty and use only: versions SMB2.1/SMB3.0/SMB3.1.1; authentication_types NTLMv2/Kerberos; kerberos_ticket_encryption_type RC4-HMAC/AES-256; channel_encryption_type AES-128-CCM/AES-128-GCM/AES-256-GCM."
  }

  validation {
    condition = var.fslogix == null ? true : (
      can(regex("^[a-z0-9]{3,24}$", var.fslogix.storage_account_name)) &&
      contains(["LRS", "ZRS"], var.fslogix.replication_type) &&
      can(regex("^[a-z0-9]+(-[a-z0-9]+)*$", var.fslogix.share_name)) &&
      length(var.fslogix.share_name) >= 3 && length(var.fslogix.share_name) <= 63 &&
      var.fslogix.quota_gib >= 100 && var.fslogix.quota_gib <= 102400 &&
      floor(var.fslogix.quota_gib) == var.fslogix.quota_gib
    )
    error_message = "Use an Azure storage name (3-24 lowercase alphanumerics), LRS or ZRS, a valid 3-63 character share name, and an integer Premium share quota of 100-102400 GiB."
  }

  validation {
    condition = var.fslogix == null ? true : (
      var.fslogix.create_resource_group || try(length(trimspace(var.fslogix.resource_group_name)) > 0, false)
    )
    error_message = "resource_group_name is required when create_resource_group is false."
  }

  validation {
    condition = var.fslogix == null ? true : (
      length(var.fslogix.user_group_ids) > 0 && length(var.fslogix.administrator_group_ids) > 0 &&
      alltrue([for id in concat(values(var.fslogix.user_group_ids), values(var.fslogix.administrator_group_ids)) :
        can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", id))
      ])
    )
    error_message = "Provide nonempty user and approved administrator maps containing Entra group object UUIDs, not display names."
  }
}
