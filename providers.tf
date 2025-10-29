terraform {
  required_version = "~> 1.5"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azapi = {
      source = "azure/azapi"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}