output "vpn_server_id" {
  description = "The ID of the VPN Server Configuration."
  value       = azurerm_vpn_server_configuration.this.id
}

output "vpn_server_name" {
  description = "The name of the VPN Server Configuration."
  value       = azurerm_vpn_server_configuration.this.name
}

output "p2s_gateway_id" {
  description = "The ID of the Point-to-Site VPN Gateway."
  value       = azapi_resource.p2s_vpn_gateway.id
}

output "p2s_gateway_name" {
  description = "The name of the Point-to-Site VPN Gateway."
  value       = azapi_resource.p2s_vpn_gateway.name
}

output "p2s_vpn_gateway" {
  description = "The complete Point-to-Site VPN Gateway resource."
  value       = azapi_resource.p2s_vpn_gateway
}

output "policy_group_ids" {
  description = "Map of VPN Server Configuration Policy Group IDs."
  value = {
    for key, pg in azurerm_vpn_server_configuration_policy_group.this : key => pg.id
  }
}

output "vpn_profiles" {
  description = "Map of configured VPN profiles with their address pools."
  value = var.p2s_configuration != null ? {
    for key, config in var.p2s_configuration : key => {
      name                = config.name
      address_pool        = config.vpn_client_address_pool.address_prefixes
      has_routing         = config.route != null
      policy_associations = try(config.configuration_policy_group_associations, [])
    }
  } : {}
}
