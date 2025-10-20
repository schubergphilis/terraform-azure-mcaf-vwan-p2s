terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = ">= 2.0"
    }
  }
}

data "azurerm_client_config" "current" {}

locals {
  tags = tomap({
    "deploymentmodel" = "Terraform",
    "environment"     = "demo",
  })
}

module "vwan" {
  source = "github.com/schubergphilis/terraform-azure-mcaf-vwan?ref=v0.8.3"

  resource_group_name = "vwan-rg"
  location            = "westeurope"

  virtual_wan = {
    name     = "vwan"
    location = "westeurope"
  }

  virtual_hubs = {
    weu = {
      virtual_hub_name                  = "westeurope"
      location                          = "westeurope"
      firewall_name                     = "firewall-weu"
      firewall_policy_name              = "firewall-policy-weu"
      routing_intent_name               = "routing-intent-weu"
      address_prefix                    = "10.10.0.0/23"
      firewall_sku_tier                 = "Standard"
      firewall_zones                    = ["1", "2", "3"]
      firewall_public_ip_count          = 1
      firewall_threat_intelligence_mode = "Alert"
      firewall_dns_proxy_enabled        = true
      firewall_dns_servers              = ["10.10.0.132"]

    }
  }

  tags = merge(
    try(local.tags, {}),
    tomap({
      "Resource Type" = "Resource Group"
    })
  )
}

module "p2s" {
  source = "../../"

  resource_group_name = "vwan-rg"
  location            = "westeurope"
  virtual_hub_id      = module.vwan.vhub_ids["weu"]

  # VPN Server Configuration - AAD authentication (bare minimum)
  vpn_server_configuration = {
    name = "vpnserverconfig"
    azure_active_directory_authentication = {
      audience = "c632b3df-fb67-4d84-bdcf-b95ad541b5c8"
      tenantid = data.azurerm_client_config.current.tenant_id
    }
  }

  # P2S Gateway - minimal required configuration
  p2s_gateway = {
    name = "vpnserverconfig-p2s"
  }

  # VPN Server Policy Groups - access control rules
  vpn_server_policy_group = {
    default = {
      name       = "AllUsers"
      is_default = true
      priority   = 0
      policy = {
        "1" = {
          name  = "AllUsers"
          type  = "AADGroupId"
          value = "00000000-0000-0000-0000-000000000000" # Replace with your AD Group Object ID
        }
      }
    }
  }

  # P2S Connection Configurations - IP pools and routing
  p2s_configuration = {
    default = {
      name = "Default"
      vpn_client_address_pool = {
        address_prefixes = ["10.10.10.0/24"]
      }
      configuration_policy_group_associations = ["default"]

      # Optional: Add routing configuration if needed
      route = {
        associated_route_table_id = module.vwan.vhub_default_route_table_ids["weu"]
        propagated_route_table = {
          ids = [module.vwan.vhub_default_route_table_ids["weu"]]
        }
      }
    }
  }

  tags = local.tags
}
