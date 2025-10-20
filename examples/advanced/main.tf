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

# Example showing a full VWAN setup with P2S VPN
module "vwan" {
  source = "github.com/schubergphilis/terraform-azure-mcaf-vwan?ref=v0.8.3"

  resource_group_name = "vwan-advanced-rg"
  location            = "westeurope"

  virtual_wan = {
    name     = "vwan-advanced"
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

# Example Route Maps for advanced routing scenarios
resource "azurerm_route_map" "inbound" {
  name           = "p2s-inbound-routemap"
  virtual_hub_id = module.vwan.vhub_ids["weu"]

  rule {
    name = "add-community"

    action {
      type = "Add"
      parameter {
        as_path = ["65001:100"]
      }
    }

    match_criterion {
      match_condition = "Contains"
      route_prefix    = ["10.10.10.0/24"]
    }
  }
}

resource "azurerm_route_map" "outbound" {
  name           = "p2s-outbound-routemap"
  virtual_hub_id = module.vwan.vhub_ids["weu"]

  rule {
    name = "prepend-path"

    action {
      type = "Add"
      parameter {
        as_path = ["65001", "65001"]
      }
    }
  }
}

# Advanced P2S VPN Configuration with all features
module "p2s_advanced" {
  source = "../../"

  resource_group_name = "vwan-advanced-rg"
  location            = "westeurope"
  virtual_hub_id      = module.vwan.vhub_ids["weu"]

  # VPN Server Configuration with multiple authentication methods
  vpn_server_configuration = {
    name                     = "vpnserverconfig-advanced"
    vpn_authentication_types = ["AAD", "Certificate", "Radius"]
    vpn_protocols            = ["OpenVPN", "IkeV2"]

    # Azure Active Directory authentication
    azure_active_directory_authentication = {
      audience = "c632b3df-fb67-4d84-bdcf-b95ad541b5c8" # Custom App Registration recommended
      tenantid = data.azurerm_client_config.current.tenant_id
    }

    # Certificate-based authentication
    client_root_certificate = {
      name             = "RootCA"
      public_cert_data = <<-EOT
        MIIC5jCCAc6gAwIBAgIQCCOPyMI5eBT4zeMaJpGFkjANBgkqhkiG9w0BAQsFADAW
        MRQwEgYDVQQDDAtQMlNSb290Q2VydDAeFw0yNDAxMDEwMDAwMDBaFw0yNTAxMDEw
        # ... (replace with your actual certificate)
      EOT
    }

    # Optional: Client certificate revocation list
    client_revoked_certificate = {
      name       = "RevokedClient1"
      thumbprint = "AABBCCDDEEFF00112233445566778899AABBCCDD"
    }

    # RADIUS authentication configuration
    radius = {
      server = [
        {
          address = "10.0.0.10"
          secret  = "radius-secret-primary"
          score   = 30
        },
        {
          address = "10.0.0.11"
          secret  = "radius-secret-secondary"
          score   = 20
        }
      ]

      # RADIUS server root certificate for secure communication
      server_root_certificate = [
        {
          name             = "RadiusServerCert"
          public_cert_data = <<-EOT
            MIIC5jCCAc6gAwIBAgIQCCOPyMI5eBT4zeMaJpGFkjANBgkqhkiG9w0BAQsFADAW
            MRQwEgYDVQQDDAtSYWRpdXNSb290MB4XDTI0MDEwMTAwMDAwMFoXDTI1MDEwMTAw
            # ... (replace with your actual RADIUS server certificate)
          EOT
        }
      ]

      # Optional: Client root certificates for RADIUS
      client_root_certificate = [
        {
          name       = "RadiusClientCert"
          thumbprint = "FFEEDDCCBBAA99887766554433221100FFEEDDCC"
        }
      ]
    }

    # IPsec policy configuration (only works with IkeV2)
    ipsec_policy = {
      dh_group               = "ECP384"
      ike_encryption         = "GCMAES256"
      ike_integrity          = "SHA384"
      ipsec_encryption       = "GCMAES256"
      ipsec_integrity        = "GCMAES256"
      pfs_group              = "ECP384"
      sa_data_size_kilobytes = 4194304
      sa_lifetime_seconds    = 28800
    }
  }

  # P2S Gateway configuration
  p2s_gateway = {
    name                                = "vpnserver-advanced-p2s"
    scale_unit                          = 2 # Increased for production
    dns_servers                         = ["10.10.0.132", "10.10.0.133"]
    routing_preference_internet_enabled = false
  }

  # Global setting: Enable forced tunneling by default (can be overridden per profile)
  internet_security_enabled = true

  # Advanced VPN Server Policy Groups with multiple access levels
  vpn_server_policy_group = {
    # Group 1: Administrators - Full access
    administrators = {
      name       = "Administrators"
      is_default = false
      priority   = 0 # Highest priority (lowest number)
      policy = {
        "1" = {
          name  = "Administrators"
          type  = "AADGroupId"
          value = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee" # Replace with Admin Group Object ID
        }
      }
    }

    # Group 2: Developers - Standard access
    developers = {
      name       = "Developers"
      is_default = false
      priority   = 1
      policy = {
        "1" = {
          name  = "Developers"
          type  = "AADGroupId"
          value = "bbbbbbbb-cccc-dddd-eeee-ffffffffffff" # Replace with Developers Group Object ID
        }
      }
    }

    # Group 3: Partners - Limited access
    partners = {
      name       = "Partners"
      is_default = false
      priority   = 2
      policy = {
        "1" = {
          name  = "Partners"
          type  = "AADGroupId"
          value = "cccccccc-dddd-eeee-ffff-aaaaaaaaaaaa" # Replace with Partners Group Object ID
        }
      }
    }

    # Group 4: Certificate-based access
    certificate_users = {
      name       = "CertificateUsers"
      is_default = false
      priority   = 3
      policy = {
        "1" = {
          name  = "CertificateUsers"
          type  = "CertificateGroupId"
          value = "OU=VPN Users,DC=contoso,DC=com" # Certificate CN/OU matching
        }
      }
    }

    # Group 5: Default/Honeypot - Isolated network (catches unmatched users)
    honeycomb = {
      name       = "Honeycomb"
      is_default = true # Default policy group for unmatched users
      priority   = 10   # Lowest priority (highest number)
      policy = {
        "1" = {
          name  = "Honeycomb"
          type  = "AADGroupId"
          value = "dddddddd-eeee-ffff-aaaa-bbbbbbbbbbbb" # Replace with Honeypot Group Object ID
        }
      }
    }
  }

  # Advanced P2S Configurations with multiple access levels
  p2s_configuration = {
    # Configuration 1: Administrators - Full access with route maps and forced tunneling
    administrators = {
      name = "Administrators-Config"
      vpn_client_address_pool = {
        address_prefixes = ["10.10.10.0/25"]
      }

      configuration_policy_group_associations = ["administrators"]

      route = {
        associated_route_table_id = module.vwan.vhub_default_route_table_ids["weu"]
        propagated_route_table = {
          labels = ["default", "admin"]
          ids    = [module.vwan.vhub_default_route_table_ids["weu"]]
        }
        inbound_route_map_id  = azurerm_route_map.inbound.id
        outbound_route_map_id = azurerm_route_map.outbound.id
      }

      # Inherit global internet_security_enabled = true (forced tunneling)
    }

    # Configuration 2: Developers - Standard access
    developers = {
      name = "Developers-Config"
      vpn_client_address_pool = {
        address_prefixes = ["10.10.10.128/26"]
      }

      configuration_policy_group_associations = ["developers"]

      route = {
        associated_route_table_id = module.vwan.vhub_default_route_table_ids["weu"]
        propagated_route_table = {
          labels = ["default"]
          ids    = [module.vwan.vhub_default_route_table_ids["weu"]]
        }
      }
    }

    # Configuration 3: Partners - Limited access with split tunneling (override global setting)
    partners = {
      name = "Partners-Config"
      vpn_client_address_pool = {
        address_prefixes = ["10.10.10.192/26"]
      }

      configuration_policy_group_associations = ["partners"]

      route = {
        associated_route_table_id = "${module.vwan.vhub_ids["weu"]}/hubRouteTables/noneRouteTable"
        propagated_route_table = {
          ids = ["${module.vwan.vhub_ids["weu"]}/hubRouteTables/noneRouteTable"]
        }
      }

      # Override: Allow split tunneling for partners (only specific traffic through VPN)
      internet_security_enabled = false
    }

    # Configuration 4: Certificate-based access
    certificate_users = {
      name = "CertificateUsers-Config"
      vpn_client_address_pool = {
        address_prefixes = ["10.10.11.0/26"]
      }

      configuration_policy_group_associations = ["certificate_users"]

      route = {
        associated_route_table_id = module.vwan.vhub_default_route_table_ids["weu"]
        propagated_route_table = {
          ids = [module.vwan.vhub_default_route_table_ids["weu"]]
        }
      }
    }

    # Configuration 5: Default/Honeypot - Isolated network (NO routing)
    # This catches any unmatched users and isolates them
    honeycomb = {
      name = "Honeycomb-Config"
      vpn_client_address_pool = {
        address_prefixes = ["10.10.11.128/25"]
      }

      configuration_policy_group_associations = ["honeycomb"]
      # No route block = completely isolated (honeypot approach for security)
      # Inherit global internet_security_enabled = true
    }
  }

  tags = merge(
    local.tags,
    tomap({
      "Component" = "P2S VPN Gateway"
    })
  )
}

# Outputs for reference
output "vpn_server_config_id" {
  description = "VPN Server Configuration ID"
  value       = module.p2s_advanced.vpn_server_id
}

output "p2s_gateway_id" {
  description = "Point-to-Site VPN Gateway ID"
  value       = module.p2s_advanced.p2s_gateway_id
}

output "vpn_profiles" {
  description = "Configured VPN Profiles"
  value = {
    server_id     = module.p2s_advanced.vpn_server_id
    gateway_id    = module.p2s_advanced.p2s_gateway_id
    policy_groups = module.p2s_advanced.policy_group_ids
  }
}
