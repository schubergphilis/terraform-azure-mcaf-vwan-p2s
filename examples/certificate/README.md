# Certificate-Based Authentication Example

This example demonstrates how to configure a Point-to-Site VPN Gateway using **Certificate Authentication only** (without Azure Active Directory).

## Overview

This configuration shows:
- ✅ **Certificate-only authentication** (no Azure AD required)
- ✅ **Multiple VPN profiles** based on certificate DN (Distinguished Name)
- ✅ **Split tunneling** for regular users, **forced tunneling** for admins
- ✅ **IPsec policy** configuration for IkeV2 protocol
- ✅ **Certificate revocation** support (optional)

## Authentication Flow

1. **Client Certificate Validation**: User's client certificate is validated against the root certificate configured in the VPN Server Configuration
2. **Policy Group Matching**: Certificate subject DN is matched against `CertificateGroupId` policies
3. **Profile Assignment**: User is assigned to the matching VPN profile (IP pool, routing, security settings)

## Certificate Structure

### Root Certificate
- **Purpose**: Validates all client certificates
- **Location**: Configured in `vpn_server_configuration.client_root_certificate`
- **Format**: Base64-encoded X.509 certificate (public key only)

### Client Certificates
- **Purpose**: User authentication
- **Requirements**:
  - Must be signed by the root certificate
  - Must have Enhanced Key Usage for Client Authentication (OID: 1.3.6.1.5.5.7.3.2)
  - Subject DN must match one of the configured policy groups

## VPN Profiles in This Example

### 1. Default Users (`default_users`)
- **IP Pool**: `10.10.10.0/24`
- **Certificate Match**: `OU=VPN Users,DC=contoso,DC=com`
- **Security**: Split tunneling (only corporate traffic through VPN)
- **Priority**: Default (catches all certificate users)

### 2. Admin Users (`admin_users`)
- **IP Pool**: `10.10.11.0/24`
- **Certificate Match**: `OU=VPN Admins,DC=contoso,DC=com`
- **Security**: Forced tunneling (all traffic through VPN)
- **Priority**: Higher priority (priority = 1)
- **Routing**: Additional route labels for admin access

## Certificate DN Matching

The `CertificateGroupId` policy type matches against the certificate's subject Distinguished Name (DN):

```
Example Certificate Subject:
CN=john.doe@contoso.com,OU=VPN Users,DC=contoso,DC=com

Policy Match:
value = "OU=VPN Users,DC=contoso,DC=com"  ✅ Match!

Example Admin Certificate Subject:
CN=admin@contoso.com,OU=VPN Admins,DC=contoso,DC=com

Policy Match:
value = "OU=VPN Admins,DC=contoso,DC=com"  ✅ Match!
```

## Generating Certificates

### Option 1: PowerShell (Windows - Self-Signed for Testing)

```powershell
# 1. Generate root certificate
$rootCert = New-SelfSignedCertificate -Type Custom -KeySpec Signature `
  -Subject "CN=P2SRootCert" -KeyExportPolicy Exportable `
  -HashAlgorithm sha256 -KeyLength 2048 `
  -CertStoreLocation "Cert:\CurrentUser\My" `
  -KeyUsageProperty Sign -KeyUsage CertSign

# 2. Export root certificate public key (Base64)
$rootCertBase64 = [System.Convert]::ToBase64String($rootCert.RawData)
Write-Output $rootCertBase64  # Use this in client_root_certificate.public_cert_data

# 3. Generate client certificate for regular user
New-SelfSignedCertificate -Type Custom -KeySpec Signature `
  -Subject "CN=user@contoso.com,OU=VPN Users,DC=contoso,DC=com" `
  -KeyExportPolicy Exportable `
  -HashAlgorithm sha256 -KeyLength 2048 `
  -CertStoreLocation "Cert:\CurrentUser\My" `
  -Signer $rootCert `
  -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.2")

# 4. Generate client certificate for admin
New-SelfSignedCertificate -Type Custom -KeySpec Signature `
  -Subject "CN=admin@contoso.com,OU=VPN Admins,DC=contoso,DC=com" `
  -KeyExportPolicy Exportable `
  -HashAlgorithm sha256 -KeyLength 2048 `
  -CertStoreLocation "Cert:\CurrentUser\My" `
  -Signer $rootCert `
  -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.2")

# 5. Export client certificate with private key (.pfx)
$clientCert = Get-ChildItem -Path "Cert:\CurrentUser\My" | Where-Object {$_.Subject -like "*OU=VPN Users*"}
$pwd = ConvertTo-SecureString -String "YourPassword" -Force -AsPlainText
Export-PfxCertificate -Cert $clientCert -FilePath "C:\vpn-client-cert.pfx" -Password $pwd
```

### Option 2: OpenSSL (Linux/Mac)

```bash
# 1. Generate root CA private key
openssl genrsa -out rootCA.key 2048

# 2. Generate root CA certificate
openssl req -x509 -new -nodes -key rootCA.key -sha256 -days 1825 \
  -out rootCA.crt -subj "/CN=P2SRootCert"

# 3. Convert root cert to Base64 (for Terraform)
openssl x509 -in rootCA.crt -outform DER | base64 -w 0

# 4. Generate client private key
openssl genrsa -out client.key 2048

# 5. Generate client certificate signing request (CSR)
openssl req -new -key client.key -out client.csr \
  -subj "/CN=user@contoso.com/OU=VPN Users/DC=contoso/DC=com"

# 6. Sign client certificate with root CA
openssl x509 -req -in client.csr -CA rootCA.crt -CAkey rootCA.key \
  -CAcreateserial -out client.crt -days 825 -sha256 \
  -extfile <(echo "extendedKeyUsage=clientAuth")

# 7. Create PKCS12 bundle for client (.pfx)
openssl pkcs12 -export -out client.pfx -inkey client.key \
  -in client.crt -certfile rootCA.crt
```

### Option 3: Active Directory Certificate Services (Production)

For production environments, use your organization's PKI:

1. Configure Certificate Template for VPN Client Authentication
2. Set appropriate Subject DN format (e.g., CN=%UPN%, OU=VPN Users)
3. Enable auto-enrollment for users
4. Export root CA certificate for Terraform configuration

## Certificate Revocation

To revoke a compromised client certificate:

```hcl
vpn_server_configuration = {
  # ... other settings ...

  client_revoked_certificate = {
    name       = "RevokedUser"
    thumbprint = "AABBCCDDEEFF00112233445566778899AABBCCDD"  # Certificate thumbprint
  }
}
```

Get certificate thumbprint:
```powershell
# PowerShell
Get-ChildItem -Path "Cert:\CurrentUser\My" | Select-Object Subject, Thumbprint

# OpenSSL
openssl x509 -in client.crt -noout -fingerprint -sha1 | sed 's/://g'
```

## Security Considerations

### ✅ Recommended
- Use proper PKI infrastructure (AD CS) in production
- Set appropriate certificate validity periods
- Implement certificate revocation procedures
- Use strong key sizes (2048-bit minimum, 4096-bit preferred)
- Protect root certificate private key
- Enable forced tunneling for sensitive users

### ❌ Not Recommended
- Self-signed certificates in production
- Sharing certificates between users
- Long certificate validity periods (>2 years)
- Storing private keys unencrypted

## Troubleshooting

### Issue: Client certificate not being recognized
**Solution**: Verify certificate has Client Authentication EKU (1.3.6.1.5.5.7.3.2)

```powershell
$cert = Get-ChildItem -Path "Cert:\CurrentUser\My\THUMBPRINT"
$cert.EnhancedKeyUsageList
# Should show "Client Authentication"
```

### Issue: User getting wrong IP pool
**Solution**: Check certificate subject DN matches policy group value exactly

```powershell
$cert = Get-ChildItem -Path "Cert:\CurrentUser\My\THUMBPRINT"
$cert.Subject
# Should match the CertificateGroupId value in the policy
```

### Issue: VPN connection fails
**Solution**:
1. Verify root certificate is correctly configured (Base64, no headers/footers)
2. Check client certificate is signed by the configured root certificate
3. Ensure certificate is not expired or revoked

## Files in This Example

- `main.tf` - Complete Terraform configuration
- `README.md` - This documentation

## Related Examples

- [../basic](../basic) - Basic Azure AD authentication
- [../advanced](../advanced) - Advanced multi-authentication setup

## References

- [Azure P2S VPN Certificate Authentication](https://learn.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-certificates-point-to-site)
- [Generate Certificates for P2S](https://learn.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-certificates-point-to-site-makecert)
- [CertificateGroupId Policy Type](https://learn.microsoft.com/en-us/azure/virtual-wan/point-to-site-vpn-groups)
