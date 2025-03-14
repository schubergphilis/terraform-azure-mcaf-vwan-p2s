terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0"
    }
  }
}

data "azurerm_client_config" "current" {}

locals {
  tags = tomap({
    "deploymentmodel" = "Terraform",
  })
}

module "vwan" {
  source = "github.com/schubergphilis/terraform-azure-mcaf-vwan?ref=v0.8.0"

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
      address_prefix                    = "10.10.0.0/23"
      firewall_sku_tier                 = "Standard"
      firewall_zones                    = ["1", "2", "3"]
      firewall_public_ip_count          = 1
      firewall_threat_intelligence_mode = "Alert"
      firewall_dns_proxy_enabled        = true
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

  resource_group_name      = "vwan-rg"
  location                 = "westeurope"
  virtual_hub_id           = module.vwan.vhub_ids["weu"]

  vpn_server_configuration = {
    name = "vpnserverconfig"
    vpn_authentication_types = ["AAD"]
    azure_active_directory_authentication = {
      audience = "c632b3df-fb67-4d84-bdcf-b95ad541b5c8"
      tenantid = data.azurerm_client_config.current.tenant_id
    }
  }

  p2s_gateway = {
    name = "vpnserverconfig-p2s"
    dns_servers = ["10.10.0.132"]
  }

  vpn_server_policy_group = {
    others = {
      name = "engineers"
      is_default = false
      priority = 0
      policy = {
        "1" = {
          name  = "<AD-Group-Name>"
          type  = "AADGroupId"
          value = "00000000-0000-0000-0000-000000000000"
        }
      }
    }
    #Should be the last one, since it will be de default
    default = {
      name = "honeycomb"
      is_default = true
      priority = 1
      policy = {
        "1" = {
          name  = "honeycomb"
          type  = "AADGroupId"
          value = "11111111-1111-1111-1111-111111111111"
        }
      }
    }
  }

  p2s_configuration = {
    others = {
      name = "Engineers"
      vpn_client_address_pool = {
        address_prefixes = ["10.10.10.0/24"]
      }
      route = {
        associated_route_table_id = module.vwan.vhub_default_route_table_ids["weu"]
        propagated_route_table = {
          ids = ["${module.vwan.vhub_ids["weu"]}/hubRouteTables/noneRouteTable"]
        }
      }
    }
    default = {
      name = "honeycomb"
      vpn_client_address_pool = {
        address_prefixes = ["10.10.11.0/25"]
      }
    }
  }

  tags = local.tags
}
