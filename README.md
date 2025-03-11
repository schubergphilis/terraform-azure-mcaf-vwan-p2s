# terraform-azure-mcaf-vwan-p2s
Azure terraform module to configure a point to site for vwan

for more documentation on the p2s for vwan with entra id, you can find it here: https://learn.microsoft.com/en-us/azure/vpn-gateway/point-to-site-entra-gateway

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
custom: `<custom-app-id>`

## Ipsec

https://learn.microsoft.com/en-us/azure/virtual-wan/point-to-site-ipsec

## open TF Issues

* [22248](https://github.com/hashicorp/terraform-provider-azurerm/issues/22248#issuecomment-1882563962)