
variable "name" {
  type        = string
  description = "shortname og the hostpool. eg. aksmgt, sqlmgt"
  validation {
    condition     = length(var.name) <= 7
    error_message = "The name can be a maximum of 7 characters"
  }
}

variable "subscription_name" {
  type        = string
  description = "Name of the subscription"
}

variable "location" {
  type        = string
  description = "location for storage account"
  default     = "norwayeast"
}

variable "hostpool_location" {
  type        = string
  description = "location for workspace and hostpool"
  default     = "westeurope"
}

variable "hostconfig_disk_type" {
  type        = string
  default     = "StandardSSD_LRS"
  description = "The type of disk to use for the virtual machines in the host pool."
}

variable "hostconfig_vm_size" {
  type        = string
  default     = "Standard_D4as_v6"
  description = "The size of the virtual machines in the host pool."
}

variable "hostconfig_image_offer" {
  type        = string
  default     = "windows-11"
  description = "The offer of the image to use for the virtual machines in the host pool."
}

variable "hostconfig_image_sku" {
  type        = string
  default     = "win11-25h2-avd"
  description = "The SKU of the image to use for the virtual machines in the host pool."
}

variable "hostconfig_image_version" {
  type        = string
  default     = "26200.6584.250915"
  description = "The version of the image to use for the virtual machines in the host pool."
}

variable "hostconfig_instance_count" {
  type        = number
  default     = 1
  description = "The number of instances to create for the virtual machines in the host pool."
}

variable "hostconfig_mdm_guid" {
  type        = string
  default     = "0000000a-0000-0000-c000-000000000000"
  description = "The MDM GUID to use for the virtual machines in the host pool to join Intune"
}

variable "workspace_friendly_name" {
  type        = string
  description = "A recognisable name for the workspace"
  default     = null
}

variable "workspace_description" {
  type        = string
  description = "A description of the workspace"
  default     = null
}

variable "hostpool_friendly_name" {
  type        = string
  description = "A recognisable name for the workspace"
  default     = null
}

variable "hostpool_description" {
  type        = string
  description = "A description of the hostpool"
  default     = null
}

variable "subnet_id" {
  type        = string
  description = "The ID of the subnet that the host pool should use"
}

variable "key_vault_id" {
  type        = string
  description = "Optional. The ID of an existing Key Vault that will be used for the host pool."
  default     = null
}

variable "kv_username_secret_id" {
  type        = string
  description = "Optional. The ID of the username secret in the Key Vault."
  default     = null
}

variable "kv_password_secret_id" {
  type        = string
  description = "Optional. The ID of the password secret in the Key Vault."
  default     = null
}

variable "assign_vnet_permission" {
  type        = bool
  description = "If true, the module will assign the 'Network Contributor' role to the AVD service principal for the vnet."
  default     = true
}

variable "assign_compute_permission" {
  type        = bool
  description = "If true, the module will assign the 'Desktop Virtualization Virtual Machine Contributor' role to the Host Pool managed identity for the specified resource group."
  default     = true
}

variable "assign_vault_permission" {
  type        = bool
  description = "If true, the module will assign the 'Key Vault Secrets User' role to the Host Pool managed identity for the specified Key Vault."
  default     = true
}

variable "validate_environment" {
  type        = bool
  description = "Should the hostpool be a validation environment. Should not be enabled in production"
  default     = false
}

variable "start_vm_on_connect" {
  type        = bool
  default     = true
  description = "Should the VMs be started when a user connects to the hostpool"
}

variable "custom_rdp_properties" {
  type        = string
  default     = ""
  description = "Custom RDP properties for the hostpool. See https://docs.microsoft.com/en-us/azure/virtual-desktop/customize-rdp-properties"
}

variable "maximum_sessions_allowed" {
  type        = number
  description = "The maximum number of sessions allowed on a host in a host pool. This property is only applicable for session-based desktops."
}

variable "load_balancer_type" {
  type        = string
  default     = "DepthFirst"
  description = "The type of load balancing to use for a host pool. Possible values are: BreadthFirst, DepthFirst, Persistent"
}

variable "preferred_app_group_type" {
  type        = string
  default     = "RailApplications"
  description = "The type of preferred application group type. Possible values are: Desktop, RailApplications"
}

variable "entra_id_host_group_prefix" {
  type        = string
  default     = "MDM Windows 11 AVD Devices"
  description = "Prefix for the host group name in Entra ID"
}

######### Hostpool Scaling Variables #########

variable "enable_scaling" {
  type        = bool
  default     = true
  description = "Enable a default scaling of the hostpool"
}

variable "scaling_friendly_name" {
  type        = string
  default     = null
  description = "An optional friendly name for the scaling configuration"
}

variable "scaling_description" {
  type        = string
  default     = null
  description = "An optional description for the scaling configuration"
}

variable "scaling_timezone" {
  type        = string
  default     = "W. Europe Standard Time"
  description = "The time zone to use for the scaling configuration"
}

variable "scaling_schedules" {
  type = map(object({
    days_of_week                         = list(string)
    ramp_up_start_time                   = string
    ramp_up_load_balancing_algorithm     = optional(string)
    ramp_up_minimum_hosts_percent        = optional(number)
    ramp_up_capacity_threshold_percent   = number
    peak_start_time                      = string
    peak_load_balancing_algorithm        = optional(string)
    ramp_down_start_time                 = string
    ramp_down_load_balancing_algorithm   = optional(string)
    ramp_down_minimum_hosts_percent      = number
    ramp_down_force_logoff_users         = bool
    ramp_down_wait_time_minutes          = number
    ramp_down_notification_message       = optional(string, "This host will soon shutdown. Save your work and sign out.")
    ramp_down_capacity_threshold_percent = optional(number)
    ramp_down_stop_hosts_when            = string
    off_peak_start_time                  = string
    off_peak_load_balancing_algorithm    = optional(string)
  }))
  description = "Optionally create your own scaling schedules. See https://learn.microsoft.com/en-us/azure/virtual-desktop/autoscale-scaling-plan#configure-a-schedule"
  default = {
    "Weekdays" = {
      days_of_week                         = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
      ramp_up_start_time                   = "07:00"
      ramp_up_minimum_hosts_percent        = 0 # ensure scale to zero
      ramp_up_capacity_threshold_percent   = 50
      peak_start_time                      = "08:00"
      ramp_down_start_time                 = "16:45"
      ramp_down_minimum_hosts_percent      = 0
      ramp_down_force_logoff_users         = true
      ramp_down_wait_time_minutes          = 30
      ramp_down_capacity_threshold_percent = 100
      ramp_down_stop_hosts_when            = "ZeroActiveSessions"
      off_peak_start_time                  = "17:30"
    }
    "Sunday-patch" = {
      scaling_timezone = "UTC" # Match time zone in Github Actions Update cron as it always uses UTC
      days_of_week                         = ["Sunday"]
      ramp_up_start_time                   = "10:00"
      ramp_up_minimum_hosts_percent        = 100
      ramp_up_capacity_threshold_percent   = 100
      peak_start_time                      = "10:01"
      ramp_down_start_time                 = "12:30"
      ramp_down_minimum_hosts_percent      = 0
      ramp_down_force_logoff_users         = true
      ramp_down_wait_time_minutes          = 10
      ramp_down_capacity_threshold_percent = 100
      ramp_down_stop_hosts_when            = "ZeroActiveSessions"
      off_peak_start_time                  = "12:45"
    }
  }
}


######### Application Groups Variables #########

variable "create_app_group" {
  type        = bool
  default     = true
  description = "Whether to create an application group for the host pool"
}

variable "group_type" {
  type        = string
  default     = "Desktop"
  description = "What types of application groups to create. Can create dektop, remote app or both"
  validation {
    condition     = var.group_type == "Desktop" || var.group_type == "RemoteApp" || var.group_type == "Both"
    error_message = "variable \"type\" allowed values are \"Desktop\", \"RemoteApp\" or \"Both\""
  }
}

variable "desktop_application_group_name" {
  type        = string
  default     = "desktop"
  description = "Name of the desktop application group"
}

variable "desktop_group_friendly_name" {
  type        = string
  default     = null
  description = "Optional friendly name for the desktop application group"
}

variable "desktop_group_description" {
  type        = string
  default     = null
  description = "Optional description for the desktop application group"
}

variable "app_application_group_name" {
  type        = string
  default     = "apps"
  description = "Name of the remote application group"
}

variable "app_group_friendly_name" {
  type        = string
  default     = null
  description = "Optional friendly name for the remote application group"
}

variable "app_group_description" {
  type        = string
  default     = null
  description = "Optional description for the remote application group"
}

variable "desktop_users" {
  type        = list(string)
  default     = []
  description = "List of AAD users to assign to the desktop application group"
}

variable "desktop_groups" {
  type        = list(string)
  default     = []
  description = "List of AAD groups to assign to the desktop application group"
}

variable "app_users" {
  type        = list(string)
  default     = []
  description = "List of AAD users to assign to the remote application group"
}

variable "app_groups" {
  type        = list(string)
  default     = []
  description = "List of AAD groups to assign to the remote application group"
}

variable "applications" {
  type        = map(map(string))
  default     = {}
  description = "Map of applications to assign to the remote application group. Key is the application name, value is a map of properties. See https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_desktop_application for more information"
}