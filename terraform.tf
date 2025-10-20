terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      version = ">= 4, < 5.0"
      source  = "hashicorp/azurerm"
    }
    azapi = {
      version = ">= 2, < 3.0"
      source  = "azure/azapi"
    }
  }
}
