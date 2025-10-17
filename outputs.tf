output "vpn_server_id" {
  description = "The ID of the VPN Server Configuration."
  value       = azurerm_vpn_server_configuration.this.id
}

output "p2s_gateway_id" {
  description = "The ID of the Point-to-Site VPN Gateway."
  value       = azapi_resource.p2s_vpn_gateway.id
}
