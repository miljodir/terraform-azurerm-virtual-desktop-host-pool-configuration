
resource "azurerm_virtual_desktop_scaling_plan" "main" {
  name                = "${azurerm_resource_group.main.name}-scaling"
  location            = azapi_resource.avd_host_pool.location
  resource_group_name = azurerm_resource_group.main.name
  friendly_name       = var.scaling_friendly_name
  description         = var.scaling_description
  time_zone           = var.scaling_timezone

  dynamic "schedule" {
    for_each = var.scaling_schedules
    content {
      name                                 = schedule.key
      days_of_week                         = schedule.value["days_of_week"]
      ramp_up_start_time                   = schedule.value["ramp_up_start_time"]
      ramp_up_load_balancing_algorithm     = schedule.value["ramp_up_load_balancing_algorithm"] == null ? var.load_balancer_type : schedule.value["ramp_up_load_balancing_algorithm"]
      ramp_up_minimum_hosts_percent        = schedule.value["ramp_up_minimum_hosts_percent"]
      ramp_up_capacity_threshold_percent   = schedule.value["ramp_up_capacity_threshold_percent"]
      peak_start_time                      = schedule.value["peak_start_time"]
      peak_load_balancing_algorithm        = schedule.value["peak_load_balancing_algorithm"] == null ? var.load_balancer_type : schedule.value["peak_load_balancing_algorithm"]
      ramp_down_start_time                 = schedule.value["ramp_down_start_time"]
      ramp_down_load_balancing_algorithm   = schedule.value["ramp_down_load_balancing_algorithm"] == null ? var.load_balancer_type : schedule.value["ramp_down_load_balancing_algorithm"]
      ramp_down_minimum_hosts_percent      = schedule.value["ramp_down_minimum_hosts_percent"]
      ramp_down_force_logoff_users         = schedule.value["ramp_down_force_logoff_users"]
      ramp_down_wait_time_minutes          = schedule.value["ramp_down_wait_time_minutes"]
      ramp_down_notification_message       = schedule.value["ramp_down_notification_message"]
      ramp_down_capacity_threshold_percent = schedule.value["ramp_down_capacity_threshold_percent"]
      ramp_down_stop_hosts_when            = schedule.value["ramp_down_stop_hosts_when"]
      off_peak_start_time                  = schedule.value["off_peak_start_time"]
      off_peak_load_balancing_algorithm    = schedule.value["off_peak_load_balancing_algorithm"] == null ? var.load_balancer_type : schedule.value["off_peak_load_balancing_algorithm"]
    }
  }
  host_pool {
    hostpool_id          = azapi_resource.avd_host_pool.id
    scaling_plan_enabled = var.enable_scaling
  }
}
