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
  })
  default = null

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
