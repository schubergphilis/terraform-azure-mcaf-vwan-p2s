resource "azurerm_vpn_server_configuration" "this" {
  resource_group_name      = var.resource_group_name
  location                 = var.location
  name                     = var.vpn_server_configuration.name
  vpn_authentication_types = var.vpn_server_configuration.vpn_authentication_types
  vpn_protocols            = var.vpn_server_configuration.vpn_protocols

  dynamic "azure_active_directory_authentication" {
    for_each = var.vpn_server_configuration.azure_active_directory_authentication != null ? [1] : []

    content {
      audience = var.vpn_server_configuration.azure_active_directory_authentication.audience
      tenant   = "https://login.microsoftonline.com/${var.vpn_server_configuration.azure_active_directory_authentication.tenantid}"
      issuer   = "https://sts.windows.net/${var.vpn_server_configuration.azure_active_directory_authentication.tenantid}/"
    }
  }

  dynamic "client_root_certificate" {
    for_each = var.vpn_server_configuration.client_root_certificate != null ? [1] : []

    content {
      name             = var.vpn_server_configuration.client_root_certificate.name
      public_cert_data = var.vpn_server_configuration.client_root_certificate.public_cert_data
    }
  }

  dynamic "client_revoked_certificate" {
    for_each = var.vpn_server_configuration.client_revoked_certificate != null ? [1] : []

    content {
      name       = var.vpn_server_configuration.client_revoked_certificate.name
      thumbprint = var.vpn_server_configuration.client_revoked_certificate.thumbprint
    }
  }

  dynamic "radius" {
    for_each = var.vpn_server_configuration.radius != null ? [1] : []

    content {
      dynamic "server" {
        for_each = var.vpn_server_configuration.radius.server

        content {
          address = server.value.address
          secret  = server.value.secret
          score   = server.value.score
        }
      }

      dynamic "client_root_certificate" {
        for_each = var.vpn_server_configuration.radius.client_root_certificate != null ? var.vpn_server_configuration.radius.client_root_certificate : []

        content {
          name       = client_root_certificate.value.name
          thumbprint = client_root_certificate.value.thumbprint
        }
      }

      dynamic "server_root_certificate" {
        for_each = var.vpn_server_configuration.radius.server_root_certificate != null ? var.vpn_server_configuration.radius.server_root_certificate : []

        content {
          name             = server_root_certificate.value.name
          public_cert_data = server_root_certificate.value.public_cert_data
        }
      }
    }
  }

  dynamic "ipsec_policy" {
    for_each = var.vpn_server_configuration.ipsec_policy != null ? [1] : []

    content {
      sa_lifetime_seconds    = var.vpn_server_configuration.ipsec_policy.sa_lifetime_seconds
      sa_data_size_kilobytes = var.vpn_server_configuration.ipsec_policy.sa_data_size_kilobytes
      ipsec_encryption       = var.vpn_server_configuration.ipsec_policy.ipsec_encryption
      ipsec_integrity        = var.vpn_server_configuration.ipsec_policy.ipsec_integrity
      ike_encryption         = var.vpn_server_configuration.ipsec_policy.ike_encryption
      ike_integrity          = var.vpn_server_configuration.ipsec_policy.ike_integrity
      dh_group               = var.vpn_server_configuration.ipsec_policy.dh_group
      pfs_group              = var.vpn_server_configuration.ipsec_policy.pfs_group
    }
  }

  tags = merge(
    try(var.tags, {}),
    tomap({
      "Resource Type" = "VPN Server Configuration"
    })
  )
}

resource "azurerm_vpn_server_configuration_policy_group" "this" {
  for_each = var.vpn_server_policy_group != null ? var.vpn_server_policy_group : {}

  name                        = each.value.name
  vpn_server_configuration_id = azurerm_vpn_server_configuration.this.id
  is_default                  = each.value.is_default
  priority                    = each.value.priority

  dynamic "policy" {
    for_each = each.value.policy != null ? each.value.policy : {}

    content {
      name  = policy.value.name
      type  = policy.value.type
      value = policy.value.value
    }
  }
}

# uncommented for now, since this does not work well with policy group associations.
# resource "azurerm_point_to_site_vpn_gateway" "this" {
#   resource_group_name         = var.resource_group_name
#   location                    = var.location
#   name                        = var.p2s_gateway.name
#   virtual_hub_id              = var.virtual_hub_id
#   vpn_server_configuration_id = azurerm_vpn_server_configuration.this.id
#   scale_unit                  = var.p2s_gateway.scale_unit
#   dns_servers                 = var.p2s_gateway.dns_servers

#   dynamic "connection_configuration" {
#     for_each = var.p2s_configuration != null ? var.p2s_configuration : {}

#     content {
#       name                      = connection_configuration.value.name
#       internet_security_enabled = var.internet_security_enabled

#       vpn_client_address_pool {
#         address_prefixes = connection_configuration.value.vpn_client_address_pool.address_prefixes
#       }

#       dynamic "route" {
#         for_each = connection_configuration.value.route != null ? [1] : []

#         content {
#           associated_route_table_id = connection_configuration.value.route.associated_route_table_id

#           propagated_route_table {
#             labels = connection_configuration.value.route.propagated_route_table.labels
#             ids    = connection_configuration.value.route.propagated_route_table.ids
#           }
#         }
#       }
#     }
#   }

#   routing_preference_internet_enabled = var.p2s_gateway.routing_preference_internet_enabled

#   tags = merge(
#     try(var.tags, {}),
#     tomap({
#       "Resource Type" = "Point-to-Site VPN Gateway"
#     })
#   )
# }


data "azurerm_subscription" "current" {}
resource "azapi_resource" "p2s_vpn_gateway" {
  type      = "Microsoft.Network/p2sVpnGateways@2024-10-01"
  parent_id = "/subscriptions/${data.azurerm_subscription.current.subscription_id}/resourceGroups/${var.resource_group_name}"
  location  = var.location
  name      = var.p2s_gateway.name

  body = {
    properties = {
      virtualHub = {
        id = var.virtual_hub_id
      }
      vpnServerConfiguration = {
        id = azurerm_vpn_server_configuration.this.id
      }
      vpnGatewayScaleUnit         = var.p2s_gateway.scale_unit
      customDnsServers            = var.p2s_gateway.dns_servers
      isRoutingPreferenceInternet = var.p2s_gateway.routing_preference_internet_enabled
      p2SConnectionConfigurations = [
        for key, config in(var.p2s_configuration != null ? var.p2s_configuration : {}) : {
          name = config.name
          properties = merge(
            {
              vpnClientAddressPool = {
                addressPrefixes = config.vpn_client_address_pool.address_prefixes
              }
              enableInternetSecurity = var.internet_security_enabled
            },
            config.route != null ? {
              routingConfiguration = merge(
                {
                  associatedRouteTable = {
                    id = config.route.associated_route_table_id
                  }
                  propagatedRouteTables = {
                    labels = config.route.propagated_route_table.labels
                    ids = [
                      for route_table_id in config.route.propagated_route_table.ids : {
                        id = route_table_id
                      }
                    ]
                  }
                },
                config.route.inbound_route_map_id != null ? {
                  inboundRouteMap = {
                    id = config.route.inbound_route_map_id
                  }
                } : {},
                config.route.outbound_route_map_id != null ? {
                  outboundRouteMap = {
                    id = config.route.outbound_route_map_id
                  }
                } : {}
              )
            } : {},
            config.configuration_policy_group_associations != null ? {
              configurationPolicyGroupAssociations = [
                for policy_group_key in config.configuration_policy_group_associations : {
                  id = azurerm_vpn_server_configuration_policy_group.this[policy_group_key].id
                }
              ]
            } : {}
          )
        }
      ]
    }
  }

  tags = merge(
    try(var.tags, {}),
    tomap({
      "Resource Type" = "Point-to-Site VPN Gateway"
    })
  )

  depends_on = [
    azurerm_vpn_server_configuration.this,
    azurerm_vpn_server_configuration_policy_group.this
  ]
}

# Migration from azurerm provider to azapi provider for P2S VPN Gateway, due to issues with group assigenments
moved {
  from = azurerm_point_to_site_vpn_gateway.this
  to   = azapi_resource.p2s_vpn_gateway
}
