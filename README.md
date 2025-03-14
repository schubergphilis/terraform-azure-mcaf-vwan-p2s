# terraform-azure-mcaf-vwan-p2s
Azure terraform module to configure a point to site for vwan

for more documentation on the p2s for vwan with entra id, you can find it here: https://learn.microsoft.com/en-us/azure/vpn-gateway/point-to-site-entra-gateway

**NOTE** Read the following!!!;

Due to open issues in the terraform provider its currently necesary to manually connect the correct AD groups to the correct ip spaces/configurations.
so make sure to go into the p2s config of your hub, and open the Groups and address pools, then connect the AD groups to the correct configs!

**Advised**

Create an Default group, which has an ip space which we do not route, like a honeypot.
so if misconfiguration ever occurs, users do not have access to anything by default.

## EntraID Configuration

Audience will either be:

Microsoft-registered: `c632b3df-fb67-4d84-bdcf-b95ad541b5c8`
Manually registered:
```
- Azure Public: 41b23e61-6c1e-4545-b367-cd054e0ed4b4
- Azure Government: 51bb15d4-3a4f-4ebf-9dca-40096fe32426
- Azure Germany: 538ee9e6-310a-468d-afef-ea97365856a9
- Microsoft Azure operated by 21Vianet: 49f817b6-84ae-4cc0-928c-73f27289b3aa
```

SBP Preferred:

custom: `<custom-app-id>`

Why? it gives you the flexibility of adding groups to the enterprise apps, which gives an extra layer of security to our vpn solution.

steps:

1. Create an App registration -> [Application](https://learn.microsoft.com/en-us/azure/virtual-wan/point-to-site-entra-register-custom-app#register-an-application)
2. Expose an API and add a scope
3. Add the Azure VPN Client application
4. Add API permissions (Delegated)
   1. User.Read (Default)
   2. User.ReadBasic.All
5. Grant admin consent for those permissions.
6. Go to overview -> click the name of the app behind 'Managed application in local directory' this will bring you to the enterprise app.
7. Go to properties -> set Assignment required? to Yes! and save at the top.
8. now assign a group to the app, under users and groups.

These groups will only have connect permissions to this VPN Solution.

## Helpfull links

[Ipsec](https://learn.microsoft.com/en-us/azure/virtual-wan/point-to-site-ipsec)

[ScaleUnits](https://learn.microsoft.com/en-us/azure/virtual-wan/virtual-wan-faq#what-is-a-virtual-wan-gateway-scale-unit)

## open TF Issues

* [22248](https://github.com/hashicorp/terraform-provider-azurerm/issues/22248#issuecomment-1882563962)

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4, < 5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | >= 4, < 5.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_point_to_site_vpn_gateway.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/point_to_site_vpn_gateway) | resource |
| [azurerm_vpn_server_configuration.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/vpn_server_configuration) | resource |
| [azurerm_vpn_server_configuration_policy_group.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/vpn_server_configuration_policy_group) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_location"></a> [location](#input\_location) | The location where the maintenance configuration will be created. | `string` | n/a | yes |
| <a name="input_p2s_configuration"></a> [p2s\_configuration](#input\_p2s\_configuration) | The connection configuration for the Point-to-Site VPN Gateway.<br><br>  `name` - (Optional) The name of the connection configuration.<br>  `internet_security_enabled` - (Optional) Whether internet security is enabled for the connection configuration.<br>  `vpn_client_address_pool` - (Required) The VPN Client Address Pool configuration.<br>    `address_prefixes` - (Required) A list of address prefixes for the VPN Client Address Pool.<br>  `route` - (Optional) The route configuration for the connection configuration.<br>    `associated_route_table_id` - (Required) The ID of the associated route table.<br>    `propagated_route_table` - (Required) The propagated route table configuration.<br>      `labels` - (Optional) A list of labels for the propagated route table.<br>      `ids` - (Required) A list of IDs for the propagated route table. | <pre>map(object({<br>    name                      = optional(string, "P2SConnectionConfigDefault")<br>    internet_security_enabled = optional(bool, true)<br>    vpn_client_address_pool = object({<br>      address_prefixes = list(string)<br>    })<br>    route = optional(object({<br>      associated_route_table_id = string<br>      propagated_route_table = object({<br>        labels = optional(list(string), ["none"])<br>        ids    = list(string)<br>      })<br>    }), null)<br>  }))</pre> | n/a | yes |
| <a name="input_p2s_gateway"></a> [p2s\_gateway](#input\_p2s\_gateway) | The Point-to-Site VPN Gateway configuration.<br><br>  `name` - (Optional) The name of the Point-to-Site VPN Gateway.<br>  `routing_preference_internet_enabled` - (Optional) Whether the Point-to-Site VPN Gateway should be enabled for internet routing.<br>  `dns_servers` - (Optional) A list of DNS Servers to be used by the Point-to-Site VPN Gateway.<br>  `scale_unit` - (Optional) The scale unit of the Point-to-Site VPN Gateway. | <pre>object({<br>    name                                = optional(string, "p2s")<br>    routing_preference_internet_enabled = optional(bool, false)<br>    dns_servers                         = optional(list(string), [])<br>    scale_unit                          = optional(number, 1)<br>  })</pre> | n/a | yes |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | The name of the resource group in which the vpn server configuration will be created. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to assign to the resources. | `map(string)` | n/a | yes |
| <a name="input_virtual_hub_id"></a> [virtual\_hub\_id](#input\_virtual\_hub\_id) | The ID of the Virtual Hub to associate with the VPN Server Configuration. | `string` | n/a | yes |
| <a name="input_vpn_server_configuration"></a> [vpn\_server\_configuration](#input\_vpn\_server\_configuration) | A VPN Server Configuration block supports the following:<br><br>  `name` - (Required) The name of the VPN Server Configuration.<br>  `vpn_authentication_types` - (Required) A list of Authentication Types applicable for this VPN Server Configuration. Possible values are AAD (Azure Active Directory), Certificate.<br>  `azure_active_directory_authentication` - (Optional) An Azure Active Directory Authentication block as defined below.<br>    `audience` - (Required) The audience of the Azure Active Directory Authentication.<br>    `tenantid` - (Required) The tenant ID of the Azure Active Directory Authentication.<br>  `ipsec_policy` - (Optional) An IPsec Policy block as defined below, works only with IKEv2.<br>    `dh_group` - (Required) The Diffie-Hellman Group for the IPsec Policy.<br>    `ike_encryption` - (Required) The IKE Encryption for the IPsec Policy.<br>    `ike_integrity` - (Required) The IKE Integrity for the IPsec Policy.<br>    `ipsec_encryption` - (Required) The IPsec Encryption for the IPsec Policy.<br>    `ipsec_integrity` - (Required) The IPsec Integrity for the IPsec Policy.<br>    `pfs_group` - (Required) The Perfect Forward<br>    `sa_lifetime_seconds` - (Required) The Security Association Lifetime in seconds for the IPsec Policy.<br>    `sa_data_size_kilobytes` - (Required) The Security Association Data Size in kilobytes for the IPsec Policy.<br>  `client_root_certificate` - (Optional) The client root certificate configuration.<br>    `name` - (Required) The name of the client root certificate.<br>    `public_cert_data` - (Required) The public certificate data of the client root certificate.<br>  `client_revoked_certificate` - (Optional) The client revoked certificate configuration.<br>    `name` - (Required) The name of the client revoked certificate.<br>    `thumbprint` - (Required) The thumbprint of the client revoked certificate. | <pre>object({<br>    name                     = string<br>    vpn_authentication_types = optional(list(string), ["AAD"])<br>    vpn_protocols            = optional(list(string), ["OpenVPN"])<br>    azure_active_directory_authentication = optional(object({<br>      audience = string<br>      tenantid = string<br>    }), null)<br>    ipsec_policy = optional(object({<br>      dh_group               = string<br>      ike_encryption         = string<br>      ike_integrity          = string<br>      ipsec_encryption       = string<br>      ipsec_integrity        = string<br>      pfs_group              = string<br>      sa_lifetime_seconds    = number<br>      sa_data_size_kilobytes = number<br>    }), null)<br>    client_root_certificate = optional(object({<br>      name             = string<br>      public_cert_data = string<br>    }), null)<br>    client_revoked_certificate = optional(object({<br>      name       = string<br>      thumbprint = string<br>    }), null)<br>  })</pre> | `null` | no |
| <a name="input_vpn_server_policy_group"></a> [vpn\_server\_policy\_group](#input\_vpn\_server\_policy\_group) | A policy block supports the following:<br><br>  `name` - (Required) The Name which should be used for this VPN Server Configuration Policy Group. Changing this forces a new resource to be created.<br>  `is_default` - (Optional) Is this the default VPN Server Configuration Policy Group, there can only be one, Changing this forces a new resource to be created.<br>  `priority` - (Optional) The priority of the VPN Server Configuration Policy Group. It must be upwards (0,1,2,3), you cannot skip like (0,10,20).<br>  `policy` - (Required) A policy block as defined below.<br>    `name` - (Required) The name of the VPN Server Configuration Policy member.<br>    `type` - (Required) The attribute type of the VPN Server Configuration Policy member. Possible values are AADGroupId, CertificateGroupId, and RadiusAzureGroupId.<br>    `value` - (Required) The value of the attribute that is used for the VPN Server Configuration Policy member. | <pre>map(object({<br>    name       = string<br>    is_default = optional(bool, false)<br>    priority   = number<br>    policy = map(object({<br>      name  = string<br>      type  = string<br>      value = string<br>    }))<br>  }))</pre> | `null` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
