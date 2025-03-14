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

<!-- END_TF_DOCS -->
