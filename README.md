# Azurerm Virtual Desktop Host Pool Configuration

[![Changelog](https://img.shields.io/badge/changelog-release-green.svg)](https://github.com/miljodir/terraform-azurerm-virtual-desktop-host-pool-configuration/wiki/main#changelog)
[![TF Registry](https://img.shields.io/badge/terraform-registry-blue.svg)](https://registry.terraform.io/modules/miljodir/virtual-desktop-host-pool-configuration/azurerm/)

Creates a virtual desktop host pool, workspace and app group.
This module utilizes Azure Virtual Desktop Session host management policy to automatically create sessions hosts, instead of creating virtual machines manually.
[Note: This feature is still in preview from Microsoft.](https://learn.microsoft.com/en-us/azure/virtual-desktop/host-pool-management-approaches#session-host-configuration-management-approach)