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

locals {
  tags = tomap({
    "deploymentmodel" = "Terraform",
    "environment"     = "demo",
  })
}

# Example VWAN setup
module "vwan" {
  source = "github.com/schubergphilis/terraform-azure-mcaf-vwan?ref=v0.8.3"

  resource_group_name = "vwan-cert-rg"
  location            = "westeurope"

  virtual_wan = {
    name     = "vwan-cert"
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

# Certificate-Only P2S VPN Configuration
module "p2s_certificate" {
  source = "../../"

  resource_group_name = "vwan-cert-rg"
  location            = "westeurope"
  virtual_hub_id      = module.vwan.vhub_ids["weu"]

  # VPN Server Configuration - Certificate Authentication ONLY (no Azure AD)
  vpn_server_configuration = {
    name                     = "vpnserverconfig-cert"
    vpn_authentication_types = ["Certificate"] # Certificate-only authentication
    vpn_protocols            = ["Ikev2", "OpenVPN",]

    # Root certificate for validating client certificates
    # Generate using: makecert, OpenSSL, or your PKI infrastructure
    client_root_certificate = {
      name             = "P2SRootCert"
      public_cert_data = <<-EOT
        MIIC5jCCAc6gAwIBAgIQCCOPyMI5eBT4zeMaJpGFkjANBgkqhkiG9w0BAQsFADAW
        MRQwEgYDVQQDDAtQMlNSb290Q2VydDAeFw0yNDAxMDEwMDAwMDBaFw0yNTAxMDEw
        MDAwMDBaMBYxFDASBgNVBAMMC1AyU1Jvb3RDZXJ0MIIBIjANBgkqhkiG9w0BAQEF
        AAOCAQ8AMIIBCgKCAQEAw5VKF0VYx0jO9rQ8P9nGvQsP8JYWcV4hK5xPjKnP0xDp
        # ... (replace with your actual root certificate in Base64 format)
        # Generate using PowerShell:
        # $cert = New-SelfSignedCertificate -Type Custom -KeySpec Signature `
        #   -Subject "CN=P2SRootCert" -KeyExportPolicy Exportable `
        #   -HashAlgorithm sha256 -KeyLength 2048 `
        #   -CertStoreLocation "Cert:\CurrentUser\My" `
        #   -KeyUsageProperty Sign -KeyUsage CertSign
        # $certBase64 = [System.Convert]::ToBase64String($cert.RawData)
      EOT
    }

    # Optional: Revoke specific client certificates
    # client_revoked_certificate = {
    #   name       = "RevokedClientCert"
    #   thumbprint = "AABBCCDDEEFF00112233445566778899AABBCCDD"
    # }

    # Optional: IPsec policy (only works with IkeV2 protocol)
    ipsec_policy = {
      dh_group               = "DHGroup2"
      ike_encryption         = "AES256"
      ike_integrity          = "SHA256"
      ipsec_encryption       = "AES256"
      ipsec_integrity        = "SHA256"
      pfs_group              = "PFS2"
      sa_data_size_kilobytes = 102400000
      sa_lifetime_seconds    = 27000
    }
  }

  # P2S Gateway - basic configuration
  p2s_gateway = {
    name       = "vpnserver-cert-p2s"
    scale_unit = 1
  }

  # Global setting: Split tunneling by default
  internet_security_enabled = false

  # VPN Server Policy Groups based on certificate distinguished name (DN)
  vpn_server_policy_group = {
    # Group 1: All certificate users
    all_cert_users = {
      name       = "AllCertUsers"
      is_default = true
      priority   = 0
      policy = {
        "1" = {
          name = "AllCertUsers"
          type = "CertificateGroupId"
          # Match certificates with this OU in the subject
          # Example cert subject: "CN=user@contoso.com,OU=VPN Users,DC=contoso,DC=com"
          value = "OU=VPN Users,DC=contoso,DC=com"
        }
      }
    }

    # Group 2: Admin users with different certificate DN
    admin_cert_users = {
      name       = "AdminCertUsers"
      is_default = false
      priority   = 1
      policy = {
        "1" = {
          name = "AdminCertUsers"
          type = "CertificateGroupId"
          # Match certificates with this OU in the subject
          value = "OU=VPN Admins,DC=contoso,DC=com"
        }
      }
    }
  }

  # P2S Connection Configurations
  p2s_configuration = {
    # Configuration 1: Default profile for all certificate users
    # Users are matched based on their client certificate's subject DN
    default_users = {
      name = "DefaultUsers"
      vpn_client_address_pool = {
        address_prefixes = ["10.10.10.0/24"]
      }

      configuration_policy_group_associations = ["all_cert_users"]

      route = {
        associated_route_table_id = module.vwan.vhub_default_route_table_ids["weu"]
        propagated_route_table = {
          ids = [module.vwan.vhub_default_route_table_ids["weu"]]
        }
      }
    }

    # Configuration 2: Separate profile for admin users
    admin_users = {
      name = "AdminUsers"
      vpn_client_address_pool = {
        address_prefixes = ["10.10.11.0/24"]
      }

      configuration_policy_group_associations = ["admin_cert_users"]

      route = {
        associated_route_table_id = module.vwan.vhub_default_route_table_ids["weu"]
        propagated_route_table = {
          labels = ["default", "admin"]
          ids    = [module.vwan.vhub_default_route_table_ids["weu"]]
        }
      }

      # Force all admin traffic through VPN
      internet_security_enabled = true
    }
  }

  tags = merge(
    local.tags,
    tomap({
      "Component"      = "P2S VPN Gateway",
      "Authentication" = "Certificate"
    })
  )
}

# Outputs
output "vpn_server_config_id" {
  description = "VPN Server Configuration ID"
  value       = module.p2s_certificate.vpn_server_id
}

output "p2s_gateway_id" {
  description = "Point-to-Site VPN Gateway ID"
  value       = module.p2s_certificate.p2s_gateway_id
}

output "certificate_instructions" {
  description = "Instructions for generating and using client certificates"
  value       = <<-EOT

    CERTIFICATE SETUP INSTRUCTIONS:

    1. Generate Root Certificate (already configured in this example):
       The root certificate public key is configured in the VPN Server Configuration.

    2. Generate Client Certificates:
       Each VPN user needs a client certificate signed by the root certificate.

       PowerShell example (Windows):
       ```powershell
       # First, ensure you have the root cert in your certificate store
       # Then generate a client certificate:

       $rootCert = Get-ChildItem -Path "Cert:\CurrentUser\My" | Where-Object {$_.Subject -eq "CN=P2SRootCert"}

       New-SelfSignedCertificate -Type Custom -KeySpec Signature `
         -Subject "CN=user@contoso.com,OU=VPN Users,DC=contoso,DC=com" `
         -KeyExportPolicy Exportable `
         -HashAlgorithm sha256 -KeyLength 2048 `
         -CertStoreLocation "Cert:\CurrentUser\My" `
         -Signer $rootCert `
         -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.2")
       ```

       For admin users, change OU to "VPN Admins":
       -Subject "CN=admin@contoso.com,OU=VPN Admins,DC=contoso,DC=com"

    3. Export Client Certificate:
       Export the client certificate with private key (.pfx) for distribution to users.
       Users must install this certificate in their Personal certificate store.

    4. Download VPN Client:
       - Download the VPN client package from Azure Portal
       - Install on client machine
       - Certificate will be automatically selected if installed correctly

    5. Certificate Matching:
       - Certificates are matched based on the OU (Organizational Unit) in the subject DN
       - "OU=VPN Users" users get 10.10.10.0/24 (split tunneling)
       - "OU=VPN Admins" users get 10.10.11.0/24 (forced tunneling)

    NOTE: In production, use a proper PKI infrastructure (e.g., Active Directory Certificate Services)
          instead of self-signed certificates.
  EOT
}
