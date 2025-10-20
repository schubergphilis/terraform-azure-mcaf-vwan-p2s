# terraform-azure-mcaf-vwan-p2s

Azure Terraform module to configure Point-to-Site VPN for Azure Virtual WAN.

For more documentation on P2S for vWAN with Entra ID, see: https://learn.microsoft.com/en-us/azure/vpn-gateway/point-to-site-entra-gateway

## Features

- ✅ **Flexible Authentication**: Supports Azure AD, Certificate, and RADIUS authentication
- ✅ **Advanced Routing**: Route tables, route maps, and propagation
- ✅ **Policy-Based Access**: Integration with Azure AD groups or certificates
- ✅ **Separate Configuration**: Distinct `vpn_server_policy_group` and `p2s_configuration` for proper lifecycle management

## Important Notes

⚠️ **Configuration Requirements**

When using `vpn_server_policy_group` and `p2s_configuration` variables:

1. Policy groups and connection configurations must be managed separately (not combined)
2. You must manually link policy groups to configurations via `configuration_policy_group_associations`
3. Navigate to your Virtual Hub → Point-to-site VPN → "Groups and address pools" for manual verification

### Design Decision: Why Not Unified `vpn_profiles`?

We initially tried to simplify the module by combining policy groups and connection configurations into a single `vpn_profiles` variable. However, we ran into a limitation with how Azure's VPN Gateway works.

**The Problem**:
When you delete a VPN profile, you need to delete both the policy group and the connection configuration. The issue is that Azure won't let you delete a policy group while the gateway still has connection configurations pointing to it. This happens even when you're trying to delete them at the same time.

**Why This Matters**:
Terraform processes deletions in a specific order. Since policy groups and configurations reference each other, Terraform can get stuck trying to delete them in the wrong order. We can't guarantee that one gets removed before the other, which means the deletion fails and leaves things in a bad state.

**Our Solution**:
We use separate `vpn_server_policy_group` and `p2s_configuration` variables instead. Yes, it requires more configuration code, but it's stable and reliable:
- ✅ Predictable creation and updates
- ✅ Clear resource lifecycle management
- ✅ No confusing dependencies
- ⚠️ More verbose, but bulletproof

## Usage

### Standard Configuration: Separate Policy Groups and Connection Configurations

```hcl
module "p2s_vpn" {
  source = "schubergphilis/mcaf-vwan-p2s/azure"

  resource_group_name = "my-rg"
  location            = "westeurope"
  virtual_hub_id      = azurerm_virtual_hub.hub.id

  vpn_server_configuration = {
    name = "my-vpn-config"

    azure_active_directory_authentication = {
      audience = "41b23e61-6c1e-4545-b367-cd054e0ed4b4" # Azure VPN Client
      tenantid = "your-tenant-id"
    }
  }

  p2s_gateway = {
    name = "my-p2s-gateway"
  }

  # Policy Groups - Define access control rules
  vpn_server_policy_group = {
    "Engineers" = {
      name       = "Engineers"
      is_default = false
      priority   = 0
      policy = {
        "1" = {
          name  = "EngineeringTeam"
          type  = "AADGroupId"
          value = "aaaa-bbbb-cccc-dddd" # Azure AD Group Object ID
        }
      }
    }

    "Default" = {
      name       = "AllUsers"
      is_default = true
      priority   = 1
      policy = {
        "1" = {
          name  = "AllUsers"
          type  = "AADGroupId"
          value = "xxxx-yyyy-zzzz-wwww"
        }
      }
    }
  }

  # Connection Configurations - Define IP pools and routing
  p2s_configuration = {
    "Config-Engineers" = {
      name = "Engineers-Config"
      vpn_client_address_pool = {
        address_prefixes = ["10.10.10.0/24"]
      }
      configuration_policy_group_associations = ["Engineers"]
      route = {
        associated_route_table_id = azurerm_virtual_hub_route_table.default.id
        propagated_route_table = {
          labels = ["default"]
          ids    = [azurerm_virtual_hub_route_table.default.id]
        }
      }
      internet_security_enabled = true  # Force tunneling
    }

    "Config-Default" = {
      name = "Default-Config"
      vpn_client_address_pool = {
        address_prefixes = ["10.10.11.0/24"]
      }
      configuration_policy_group_associations = ["Default"]
      internet_security_enabled = false  # No forced tunneling
    }
  }

  tags = {
    Environment = "Production"
    ManagedBy   = "Terraform"
  }
}
```

## Policy Group Priority and Evaluation Order

When a user connects to the P2S VPN, policy groups are evaluated in order based on their **`priority` field** to determine which configuration they should receive. Understanding this ordering is crucial for proper access control.

### How Priority Works

Think of priority like a checklist. Azure starts at priority 0 and works its way up. The first policy group that matches the user is the one that gets applied - then it stops checking.

**Lower number = checked first, higher number = checked last**

```
Priority 0   → Checked FIRST (gets highest priority)
Priority 1   → Checked SECOND
Priority 10  → Checked THIRD
Priority 100 → Checked LAST  (usually your default/catch-all)
```

### Key Things to Know

- ✅ **The order in the list doesn't matter** - You can list policy groups in any order
- ✅ **Only the priority numbers matter** - The `priority` field in each group determines what gets checked first
- ✅ **First match wins** - Once a user matches a group, they get that group's configuration and Azure stops looking
- ✅ **Use a catch-all group** - Always have one group with a high priority number and `is_default = true` for users who don't match anything else

### Example: Multi-Tier Access Control

```hcl
vpn_server_policy_group = {
  # Tier 1: Honeypot (isolated) - checked FIRST
  "Honeycomb" = {
    name       = "Honeycomb"
    priority   = 0        # ← FIRST - catches suspicious users
    is_default = false
    policy = {
      "1" = {
        name  = "HoneypotOU"
        type  = "AADGroupId"
        value = "honeypot-group-id"
      }
    }
  }

  # Tier 2: Administrators - checked SECOND
  "Administrators" = {
    name       = "Administrators"
    priority   = 10       # ← SECOND - full access
    is_default = false
    policy = {
      "1" = {
        name  = "AdminGroup"
        type  = "AADGroupId"
        value = "admin-group-id"
      }
    }
  }

  # Tier 3: Standard Users - checked THIRD
  "StandardUsers" = {
    name       = "StandardUsers"
    priority   = 50       # ← THIRD - limited access
    is_default = false
    policy = {
      "1" = {
        name  = "UserGroup"
        type  = "AADGroupId"
        value = "user-group-id"
      }
    }
  }

  # Tier 4: Default Catch-all - checked LAST
  "Default" = {
    name       = "Default"
    priority   = 999      # ← LAST - default for unmatched users
    is_default = true
    policy = {
      "1" = {
        name  = "Everyone"
        type  = "AADGroupId"
        value = "everyone-group-id"
      }
    }
  }
}

p2s_configuration = {
  "Corporate" = {
    name = "Corporate-VPN"
    vpn_client_address_pool = {
      address_prefixes = ["10.10.0.0/16"]
    }
    # Array order is irrelevant - priority fields determine evaluation:
    # Honeycomb (0) → Administrators (10) → StandardUsers (50) → Default (999)
    configuration_policy_group_associations = [
      "Honeycomb",
      "Administrators",
      "StandardUsers",
      "Default"
    ]
  }
}
```

### User Connection Flow

When a user connects, Azure evaluates in priority order:

```
1. Is user in "Honeycomb"? (priority 0)
   └─ YES → Isolated network (honeypot) ⚠️
   └─ NO  → Continue to next

2. Is user in "Administrators"? (priority 10)
   └─ YES → Full access 🟢
   └─ NO  → Continue to next

3. Is user in "StandardUsers"? (priority 50)
   └─ YES → Limited access 🟡
   └─ NO  → Continue to next

4. Apply "Default" (priority 999)
   └─ Fallback for unmatched users 🔵
```

## Authentication Methods

This module supports three authentication types:

### Azure Active Directory (Entra ID)

```hcl
azure_active_directory_authentication = {
  audience = "41b23e61-6c1e-4545-b367-cd054e0ed4b4" # Azure VPN Client
  tenantid = data.azurerm_client_config.current.tenant_id
}
```

⚠️ **Note on Linux Support**: Azure AD authentication works on Linux, but group-based policy filtering does not. On Linux, the VPN will ignore group membership and always assign users to the default policy group (the one with `is_default = true`), regardless of which Azure AD group they belong to. Windows and macOS clients properly evaluate which group a user belongs to. If you need group-based access control on Linux, use certificate-based or RADIUS authentication instead.

### Certificate-Based

```hcl
client_root_certificate = {
  name             = "RootCA"
  public_cert_data = <<-EOT
    MIIC5jCCAc6gAwIBAgIQCCOPyMI5eBT4zeMaJpGFkjANBgkqhkiG9w0BAQsFADAW
    # ... (Base64 encoded certificate)
  EOT
}
```

### RADIUS

```hcl
radius = {
  server = [
    {
      address = "10.0.0.10"
      secret  = "radius-secret"
      score   = 30
    }
  ]
}
```

## Advanced Features

### Forced Tunneling (Internet Security)

Force all client traffic through the VPN tunnel:

```hcl
internet_security_enabled = true  # Adds 0.0.0.0/0 route
```

### Multiple Policy Rules

You can add multiple rules to a policy group. If a user matches ANY of the rules, they get access:

```hcl
policy = {
  "1" = {
    name  = "Team A"
    type  = "AADGroupId"
    value = "aaaa-bbbb-cccc-dddd"
  }
  "2" = {
    name  = "Team B"
    type  = "AADGroupId"
    value = "eeee-ffff-gggg-hhhh"
  }
}
# If a user is in Team A OR Team B, they get this policy group's configuration
```

### Route Maps (Inbound/Outbound)

Apply custom routing transformations:

```hcl
route = {
  associated_route_table_id = azurerm_virtual_hub_route_table.default.id
  propagated_route_table = {
    labels = ["default"]
    ids    = [azurerm_virtual_hub_route_table.default.id]
  }
  inbound_route_map_id  = azurerm_route_map.inbound.id
  outbound_route_map_id = azurerm_route_map.outbound.id
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9 |
| <a name="requirement_azapi"></a> [azapi](#requirement\_azapi) | >= 2, < 3.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4, < 5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azapi"></a> [azapi](#provider\_azapi) | >= 2, < 3.0 |
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | >= 4, < 5.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azapi_resource.p2s_vpn_gateway](https://registry.terraform.io/providers/azure/azapi/latest/docs/resources/resource) | resource |
| [azurerm_vpn_server_configuration.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/vpn_server_configuration) | resource |
| [azurerm_vpn_server_configuration_policy_group.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/vpn_server_configuration_policy_group) | resource |
| [azurerm_subscription.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/subscription) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_location"></a> [location](#input\_location) | The location where the maintenance configuration will be created. | `string` | n/a | yes |
| <a name="input_p2s_gateway"></a> [p2s\_gateway](#input\_p2s\_gateway) | The Point-to-Site VPN Gateway configuration.<br><br>  `name` - (Optional) The name of the Point-to-Site VPN Gateway.<br>  `routing_preference_internet_enabled` - (Optional) Whether the Point-to-Site VPN Gateway should be enabled for internet routing or MS Backbone routing.<br>  `dns_servers` - (Optional) A list of DNS Servers to be used by the Point-to-Site VPN Gateway.<br>  `scale_unit` - (Optional) The scale unit of the Point-to-Site VPN Gateway. | <pre>object({<br>    name                                = optional(string, "p2s")<br>    routing_preference_internet_enabled = optional(bool, false)<br>    dns_servers                         = optional(list(string), [])<br>    scale_unit                          = optional(number, 1)<br>  })</pre> | n/a | yes |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | The name of the resource group in which the vpn server configuration will be created. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to assign to the resources. | `map(string)` | n/a | yes |
| <a name="input_virtual_hub_id"></a> [virtual\_hub\_id](#input\_virtual\_hub\_id) | The ID of the Virtual Hub to associate with the VPN Server Configuration. | `string` | n/a | yes |
| <a name="input_internet_security_enabled"></a> [internet\_security\_enabled](#input\_internet\_security\_enabled) | Global default for forced tunneling (adds 0.0.0.0/0 route). true = All client traffic through VPN, false = Split tunnel. Per-configuration internet\_security\_enabled in p2s\_configuration overrides this when set. | `bool` | `true` | no |
| <a name="input_p2s_configuration"></a> [p2s\_configuration](#input\_p2s\_configuration) | The connection configuration for the Point-to-Site VPN Gateway.<br><br>  `name` - (Optional) The name of the connection configuration.<br>  `vpn_client_address_pool` - (Required) The VPN Client Address Pool configuration.<br>    `address_prefixes` - (Required) A list of address prefixes for the VPN Client Address Pool.<br>  `route` - (Optional) The route configuration for the connection configuration.<br>    `associated_route_table_id` - (Required) The ID of the associated route table.<br>    `propagated_route_table` - (Required) The propagated route table configuration.<br>      `labels` - (Optional) A list of labels for the propagated route table.<br>      `ids` - (Required) A list of IDs for the propagated route table.<br>    `inbound_route_map_id` - (Optional) The ID of the inbound route map.<br>    `outbound_route_map_id` - (Optional) The ID of the outbound route map.<br>  `configuration_policy_group_associations` - (Optional) A list of policy group keys that match keys in the vpn\_server\_policy\_group map.<br>    the higher the priority (lower number), the earlier it is evaluated. 0 is highest priority and evaluated first.<br>  `internet_security_enabled` - (Optional) Whether internet security is enabled for this connection configuration.<br>    When null, uses the global internet\_security\_enabled variable. Defaults to null. | <pre>map(object({<br>    name = optional(string, "P2SConnectionConfigDefault")<br>    vpn_client_address_pool = object({<br>      address_prefixes = list(string)<br>    })<br>    route = optional(object({<br>      associated_route_table_id = string<br>      propagated_route_table = object({<br>        labels = optional(list(string), ["none"])<br>        ids    = list(string)<br>      })<br>      inbound_route_map_id  = optional(string, null)<br>      outbound_route_map_id = optional(string, null)<br>    }), null)<br>    configuration_policy_group_associations = optional(list(string), null)<br>    internet_security_enabled               = optional(bool, null) # null = use global default<br>  }))</pre> | `null` | no |
| <a name="input_vpn_server_configuration"></a> [vpn\_server\_configuration](#input\_vpn\_server\_configuration) | A VPN Server Configuration block supports the following:<br><br>  `name` - (Required) The name of the VPN Server Configuration.<br>  `vpn_authentication_types` - (Required) A list of Authentication Types applicable for this VPN Server Configuration. Possible values are AAD (Azure Active Directory), Certificate.<br>  `azure_active_directory_authentication` - (Optional) An Azure Active Directory Authentication block as defined below.<br>    `audience` - (Required) The audience of the Azure Active Directory Authentication.<br>    `tenantid` - (Required) The tenant ID of the Azure Active Directory Authentication.<br>  `ipsec_policy` - (Optional) An IPsec Policy block as defined below, works only with IKEv2.<br>    `dh_group` - (Required) The Diffie-Hellman Group for the IPsec Policy.<br>    `ike_encryption` - (Required) The IKE Encryption for the IPsec Policy.<br>    `ike_integrity` - (Required) The IKE Integrity for the IPsec Policy.<br>    `ipsec_encryption` - (Required) The IPsec Encryption for the IPsec Policy.<br>    `ipsec_integrity` - (Required) The IPsec Integrity for the IPsec Policy.<br>    `pfs_group` - (Required) The Perfect Forward<br>    `sa_lifetime_seconds` - (Required) The Security Association Lifetime in seconds for the IPsec Policy.<br>    `sa_data_size_kilobytes` - (Required) The Security Association Data Size in kilobytes for the IPsec Policy.<br>  `client_root_certificate` - (Optional) The client root certificate configuration.<br>    `name` - (Required) The name of the client root certificate.<br>    `public_cert_data` - (Required) The public certificate data of the client root certificate.<br>  `client_revoked_certificate` - (Optional) The client revoked certificate configuration.<br>    `name` - (Required) The name of the client revoked certificate.<br>    `thumbprint` - (Required) The thumbprint of the client revoked certificate. | <pre>object({<br>    name                     = string<br>    vpn_authentication_types = optional(list(string), ["AAD"])<br>    vpn_protocols            = optional(list(string), ["OpenVPN"])<br>    azure_active_directory_authentication = optional(object({<br>      audience = string<br>      tenantid = string<br>    }), null)<br>    ipsec_policy = optional(object({<br>      dh_group               = string<br>      ike_encryption         = string<br>      ike_integrity          = string<br>      ipsec_encryption       = string<br>      ipsec_integrity        = string<br>      pfs_group              = string<br>      sa_lifetime_seconds    = number<br>      sa_data_size_kilobytes = number<br>    }), null)<br>    client_root_certificate = optional(object({<br>      name             = string<br>      public_cert_data = string<br>    }), null)<br>    client_revoked_certificate = optional(object({<br>      name       = string<br>      thumbprint = string<br>    }), null)<br>    radius = optional(object({<br>      server = list(object({<br>        address = string<br>        secret  = string<br>        score   = optional(number)<br>      }))<br>      client_root_certificate = optional(list(object({<br>        name       = string<br>        thumbprint = string<br>      })), null)<br>      server_root_certificate = optional(list(object({<br>        name             = string<br>        public_cert_data = string<br>      })), null)<br>    }), null)<br>  })</pre> | `null` | no |
| <a name="input_vpn_server_policy_group"></a> [vpn\_server\_policy\_group](#input\_vpn\_server\_policy\_group) | A VPN Server Configuration Policy Group defines access control rules for P2S connections.<br><br>  `name` - (Required) The Name which should be used for this VPN Server Configuration Policy Group. Changing this forces a new resource to be created.<br>  `is_default` - (Optional) Is this the default VPN Server Configuration Policy Group, there can only be one, Changing this forces a new resource to be created.<br>  `priority` - (Optional) The priority of the VPN Server Configuration Policy Group. It must be upwards (0,1,2,3), you cannot skip like (0,10,20).<br>  `policy` - (Required) A policy block as defined below.<br>    `name` - (Required) The name of the VPN Server Configuration Policy member.<br>    `type` - (Required) The attribute type of the VPN Server Configuration Policy member. Possible values are AADGroupId, CertificateGroupId, and RadiusAzureGroupId.<br>    `value` - (Required) The value of the attribute that is used for the VPN Server Configuration Policy member. | <pre>map(object({<br>    name       = string<br>    is_default = optional(bool, false)<br>    priority   = number<br>    policy = map(object({<br>      name  = string<br>      type  = string<br>      value = string<br>    }))<br>  }))</pre> | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_p2s_gateway_id"></a> [p2s\_gateway\_id](#output\_p2s\_gateway\_id) | The ID of the Point-to-Site VPN Gateway. |
| <a name="output_p2s_gateway_name"></a> [p2s\_gateway\_name](#output\_p2s\_gateway\_name) | The name of the Point-to-Site VPN Gateway. |
| <a name="output_p2s_vpn_gateway"></a> [p2s\_vpn\_gateway](#output\_p2s\_vpn\_gateway) | The complete Point-to-Site VPN Gateway resource. |
| <a name="output_policy_group_ids"></a> [policy\_group\_ids](#output\_policy\_group\_ids) | Map of VPN Server Configuration Policy Group IDs. |
| <a name="output_vpn_profiles"></a> [vpn\_profiles](#output\_vpn\_profiles) | Map of configured VPN profiles with their address pools. |
| <a name="output_vpn_server_id"></a> [vpn\_server\_id](#output\_vpn\_server\_id) | The ID of the VPN Server Configuration. |
| <a name="output_vpn_server_name"></a> [vpn\_server\_name](#output\_vpn\_server\_name) | The name of the VPN Server Configuration. |
<!-- END_TF_DOCS -->
