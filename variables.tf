variable "resource_group_name" {
  description = "The name of the resource group in which the vpn server configuration will be created."
  type        = string
}

variable "location" {
  description = "The location where the maintenance configuration will be created."
  type        = string
}

variable "virtual_hub_id" {
  description = "The ID of the Virtual Hub to associate with the VPN Server Configuration."
  type        = string
}

variable "vpn_server_configuration" {
  type = object({
    name                     = string
    vpn_authentication_types = optional(list(string), ["AAD"])
    vpn_protocols            = optional(list(string), ["OpenVPN"])
    azure_active_directory_authentication = optional(object({
      audience = string
      tenantid = string
    }), null)
    ipsec_policy = optional(object({
      dh_group               = string
      ike_encryption         = string
      ike_integrity          = string
      ipsec_encryption       = string
      ipsec_integrity        = string
      pfs_group              = string
      sa_lifetime_seconds    = number
      sa_data_size_kilobytes = number
    }), null)
    client_root_certificate = optional(object({
      name             = string
      public_cert_data = string
    }), null)
    client_revoked_certificate = optional(object({
      name       = string
      thumbprint = string
    }), null)
    radius = optional(object({
      server = list(object({
        address = string
        secret  = string
        score   = optional(number)
      }))
      client_root_certificate = optional(list(object({
        name       = string
        thumbprint = string
      })), null)
      server_root_certificate = optional(list(object({
        name             = string
        public_cert_data = string
      })), null)
    }), null)
  })
  default     = null
  description = <<DESCRIPTION
A VPN Server Configuration block supports the following:

  `name` - (Required) The name of the VPN Server Configuration.
  `vpn_authentication_types` - (Required) A list of Authentication Types applicable for this VPN Server Configuration. Possible values are AAD (Azure Active Directory), Certificate.
  `azure_active_directory_authentication` - (Optional) An Azure Active Directory Authentication block as defined below.
    `audience` - (Required) The audience of the Azure Active Directory Authentication.
    `tenantid` - (Required) The tenant ID of the Azure Active Directory Authentication.
  `ipsec_policy` - (Optional) An IPsec Policy block as defined below, works only with IKEv2.
    `dh_group` - (Required) The Diffie-Hellman Group for the IPsec Policy.
    `ike_encryption` - (Required) The IKE Encryption for the IPsec Policy.
    `ike_integrity` - (Required) The IKE Integrity for the IPsec Policy.
    `ipsec_encryption` - (Required) The IPsec Encryption for the IPsec Policy.
    `ipsec_integrity` - (Required) The IPsec Integrity for the IPsec Policy.
    `pfs_group` - (Required) The Perfect Forward
    `sa_lifetime_seconds` - (Required) The Security Association Lifetime in seconds for the IPsec Policy.
    `sa_data_size_kilobytes` - (Required) The Security Association Data Size in kilobytes for the IPsec Policy.
  `client_root_certificate` - (Optional) The client root certificate configuration.
    `name` - (Required) The name of the client root certificate.
    `public_cert_data` - (Required) The public certificate data of the client root certificate.
  `client_revoked_certificate` - (Optional) The client revoked certificate configuration.
    `name` - (Required) The name of the client revoked certificate.
    `thumbprint` - (Required) The thumbprint of the client revoked certificate.

  DESCRIPTION

  validation {
    condition = (
      length(var.vpn_server_configuration.vpn_protocols) == 0 ||
      contains(var.vpn_server_configuration.vpn_protocols, "Ikev2") ||
      var.vpn_server_configuration.ipsec_policy == null
    )
    error_message = "The ipsec_policy can only be used if vpn_protocols includes 'Ikev2'."
  }
}

variable "p2s_gateway" {
  type = object({
    name                                = optional(string, "p2s")
    routing_preference_internet_enabled = optional(bool, false)
    dns_servers                         = optional(list(string), [])
    scale_unit                          = optional(number, 1)
  })
  description = <<DESCRIPTION
The Point-to-Site VPN Gateway configuration.

  `name` - (Optional) The name of the Point-to-Site VPN Gateway.
  `routing_preference_internet_enabled` - (Optional) Whether the Point-to-Site VPN Gateway should be enabled for internet routing.
  `dns_servers` - (Optional) A list of DNS Servers to be used by the Point-to-Site VPN Gateway.
  `scale_unit` - (Optional) The scale unit of the Point-to-Site VPN Gateway.

  DESCRIPTION
}

variable "internet_security_enabled" {
  type        = bool
  default     = true
  description = <<DESCRIPTION
    Whether internet security is enabled for the Point-to-Site VPN Gateway connections, it will include/remove 0.0.0.0/0 in the route table.
    Although it seems you can set this per connection, this is not the case.
  DESCRIPTION
}

variable "p2s_configuration" {
  type = map(object({
    name = optional(string, "P2SConnectionConfigDefault")
    vpn_client_address_pool = object({
      address_prefixes = list(string)
    })
    route = optional(object({
      associated_route_table_id = string
      propagated_route_table = object({
        labels = optional(list(string), ["none"])
        ids    = list(string)
      })
    }), null)
  }))
  description = <<DESCRIPTION
The connection configuration for the Point-to-Site VPN Gateway.

  `name` - (Optional) The name of the connection configuration.
  `internet_security_enabled` - (Optional) Whether internet security is enabled for the connection configuration.
  `vpn_client_address_pool` - (Required) The VPN Client Address Pool configuration.
    `address_prefixes` - (Required) A list of address prefixes for the VPN Client Address Pool.
  `route` - (Optional) The route configuration for the connection configuration.
    `associated_route_table_id` - (Required) The ID of the associated route table.
    `propagated_route_table` - (Required) The propagated route table configuration.
      `labels` - (Optional) A list of labels for the propagated route table.
      `ids` - (Required) A list of IDs for the propagated route table.

DESCRIPTION
}

variable "vpn_server_policy_group" {
  type = map(object({
    name       = string
    is_default = optional(bool, false)
    priority   = number
    policy = map(object({
      name  = string
      type  = string
      value = string
    }))
  }))
  default     = null
  description = <<DESCRIPTION
A policy block supports the following:

  `name` - (Required) The Name which should be used for this VPN Server Configuration Policy Group. Changing this forces a new resource to be created.
  `is_default` - (Optional) Is this the default VPN Server Configuration Policy Group, there can only be one, Changing this forces a new resource to be created.
  `priority` - (Optional) The priority of the VPN Server Configuration Policy Group. It must be upwards (0,1,2,3), you cannot skip like (0,10,20).
  `policy` - (Required) A policy block as defined below.
    `name` - (Required) The name of the VPN Server Configuration Policy member.
    `type` - (Required) The attribute type of the VPN Server Configuration Policy member. Possible values are AADGroupId, CertificateGroupId, and RadiusAzureGroupId.
    `value` - (Required) The value of the attribute that is used for the VPN Server Configuration Policy member.
  DESCRIPTION
}

variable "tags" {
  description = "A map of tags to assign to the resources."
  type        = map(string)
}