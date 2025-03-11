

resource "azurerm_vpn_server_configuration" "this" {
  resource_group_name      = var.resource_group_name
  location                 = var.location
  name                     = var.vpn_server_name
  vpn_authentication_types = var.vpn_authentication_types
  vpn_protocols            = var.vpn_protocols

  dynamic "azure_active_directory_authentication" {
    for_each = var.azure_active_directory_authentication != null ? [1] : []

    content {
      audience = var.azure_active_directory_authentication.audience
      tenant   = "https://login.microsoftonline.com/${var.azure_active_directory_authentication.tenantid}"
      issuer   = "https://sts.windows.net/${var.azure_active_directory_authentication.tenantid}/"
    }
  }

  dynamic "client_root_certificate" {
    for_each = var.client_root_certificate != null ? [var.client_root_certificate] : []

    content {
      name             = each.value.client_root_certificate.name
      public_cert_data = each.value.client_root_certificate.public_cert_data
    }
  }

  dynamic "client_revoked_certificate" {
    for_each = var.client_revoked_certificate != null ? [var.client_revoked_certificate] : []

    content {
      name       = each.value.client_revoked_certificate.name
      thumbprint = each.value.client_revoked_certificate.thumbprint
    }
  }

  dynamic "ipsec_policy" {
    for_each = var.ipsec_policy != null ? [var.ipsec_policy] : []

    content {
      sa_lifetime_seconds    = each.value.sa_lifetime_seconds
      sa_data_size_kilobytes = each.value.sa_data_size_kilobytes
      ipsec_encryption       = each.value.ipsec_encryption
      ipsec_integrity        = each.value.ipsec_integrity
      ike_encryption         = each.value.ike_encryption
      ike_integrity          = each.value.ike_integrity
      dh_group               = each.value.dh_group
      pfs_group              = each.value.pfs_group
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

resource "azurerm_point_to_site_vpn_gateway" "this" {
  resource_group_name                 = var.resource_group_name
  location                            = var.location
  name                                = var.p2s_gateway_name
  virtual_hub_id                      = var.virtual_hub_id
  vpn_server_configuration_id         = azurerm_vpn_server_configuration.this.id
  scale_unit                          = var.p2s_gateway_scale_unit
  dns_servers                         = var.p2s_dns_servers

  dynamic "connection_configuration" {
    for_each = var.p2s_configuration != null ? var.p2s_configuration : {}

    content {
      name                      = connection_configuration.value.name
      internet_security_enabled = connection_configuration.value.internet_security_enabled

      vpn_client_address_pool {
        address_prefixes = connection_configuration.value.vpn_client_address_pool.address_prefixes
      }

      route {
        associated_route_table_id = connection_configuration.value.route.associated_route_table_id

        propagated_route_table {
          labels = connection_configuration.value.route.propagated_route_table.labels
          ids    = connection_configuration.value.route.propagated_route_table.ids
        }
      }
    }
  }

  routing_preference_internet_enabled = var.routing_preference_internet_enabled

  tags = merge(
    try(var.tags, {}),
    tomap({
      "Resource Type" = "Point-to-Site VPN Gateway"
    })
  )
}
