variable "resource_group_name" {
  description = "The name of the resource group in which the vpn server configuration will be created."
  type        = string
}

variable "location" {
  description = "The location where the maintenance configuration will be created."
  type        = string
}

variable "vpn_server_name" {
  description = "The name of the VPN Server Configuration."
  type        = string
}

variable "vpn_server_policy_group" {
  type = map(object({
    name = string
    is_default = optional(bool, false)
    priority = optional(number, 0)
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
  `policy` - (Required) A policy block as defined below.
    `name` - (Required) The name of the VPN Server Configuration Policy member.
    `type` - (Required) The attribute type of the VPN Server Configuration Policy member. Possible values are AADGroupId, CertificateGroupId, and RadiusAzureGroupId.
    `value` - (Required) The value of the attribute that is used for the VPN Server Configuration Policy member.
  DESCRIPTION
}

variable "virtual_hub_id" {
  description = "The ID of the Virtual Hub to associate with the VPN Server Configuration."
  type        = string
}

variable "vpn_authentication_types" {
  description = "A list of Authentication Types applicable for this VPN Server Configuration. Possible values are AAD (Azure Active Directory), Certificate."
  type        = list(string)
  default     = null
}

variable "vpn_protocols" {
  description = "A list of VPN Protocols applicable for this VPN Server Configuration. Possible values are IkeV2 and OpenVPN."
  type        = list(string)
  default     = ["OpenVPN"]
}

variable "tags" {
  description = "A mapping of tags to assign to the resource."
  type        = map(string)
}

variable "client_root_certificate" {
  description = "The client root certificate configuration."
  type = object({
    name             = string
    public_cert_data = string
  })
  default = null
}

variable "client_revoked_certificate" {
  description = "The client revoked certificate configuration."
  type = object({
    name       = string
    thumbprint = string
  })
  default = null
}

variable "azure_active_directory_authentication" {
  description = "The Entra ID authentication configuration, you can only have one."
  type = object({
    audience = string
    tenantid = string
  })
  default = null
}

variable "ipsec_policy" {
  description = "The IPSec policy configuration."
  type = object({
    dh_group               = string
    ike_encryption         = string
    ike_integrity          = string
    ipsec_encryption       = string
    ipsec_integrity        = string
    pfs_group              = string
    sa_lifetime_seconds    = number
    sa_data_size_kilobytes = number
  })
  default = null
}

variable "p2s_gateway_name" {
  description = "The name of the Point-to-Site VPN Gateway."
  type        = string
}

variable "p2s_gateway_scale_unit" {
  description = "The number of scale units for the Point-to-Site VPN Gateway."
  type        = number
  default     = 1
}

variable "p2s_configuration" {
  description = "The connection configuration for the Point-to-Site VPN Gateway."
  type = map(object({
    name                      = optional(string, "P2SConnectionConfigDefault")
    internet_security_enabled = optional(bool, true)
    vpn_client_address_pool = object({
      address_prefixes = list(string)
    })
    route = object({
      associated_route_table_id = string
      propagated_route_table = object({
        labels = optional(list(string), ["none"])
        ids    = list(string)
      })
    })
  }))
}

variable "routing_preference_internet_enabled" {
  description = "Enable internet routing preference."
  type        = bool
  default     = false
}

variable "p2s_dns_servers" {
  description = "The list of DNS servers to use for the Point-to-Site VPN Gateway."
  type        = list(string)
}
