# LDAP Setup and Configuration Guide

## Overview
This guide covers setting up and configuring LDAP (Lightweight Directory Access Protocol) on Windows Server, including securing with SSL/TLS (LDAPS).

## Prerequisites
- Windows Server with Active Directory Domain Services installed
- SSL Certificate for LDAPS (optional but recommended)
- Administrative access

## Step 1: Verify LDAP Installation

LDAP is automatically installed with Active Directory Domain Services. To verify:

```powershell
# Check if LDAP port is listening
Test-NetConnection -ComputerName localhost -Port 389

# Check if LDAPS port is listening (if configured)
Test-NetConnection -ComputerName localhost -Port 636
```

## Step 2: Configure LDAPS (Secure LDAP)

### Generate Certificate Request
1. Open "Server Manager" > "Tools" > "Certificate Authority"
2. Right-click your CA > "Properties"
3. Generate certificate request:
```powershell
# Generate certificate request
$req = @"
[Version]
Signature=`$Windows NT`$

[NewRequest]
Subject = "CN=dc01.contoso.local"
KeySpec = 1
KeyLength = 2048
Exportable = TRUE
MachineKeySet = TRUE
SMIME = FALSE
PrivateKeyArchive = FALSE
UserProtected = FALSE
UseExistingKeySet = FALSE
ProviderName = "Microsoft RSA SChannel Cryptographic Provider"
ProviderType = 12
RequestType = PKCS10
KeyUsage = 0xa0

[EnhancedKeyUsageExtension]
OID=1.3.6.1.5.5.7.3.1
"@ 

# Save request to file
$req | Out-File -FilePath "C:\ldap_cert_request.inf" -Encoding ascii

# Create certificate request
certreq -new "C:\ldap_cert_request.inf" "C:\ldap_cert_request.req"
```

### Install Certificate
```powershell
# Install the certificate (after receiving it from CA)
certreq -accept "C:\ldap_cert.cer"
```

### Verify Certificate Installation
```powershell
# Verify certificate
Get-ChildItem -Path "Cert:\LocalMachine\My" | Where-Object {$_.Subject -like "*dc01.contoso.local*"}
```

## Step 3: Test LDAP Connectivity

### Basic LDAP Query
```powershell
# Test LDAP query
$domain = "DC=contoso,DC=local"
$searcher = New-Object DirectoryServices.DirectorySearcher([ADSI]"LDAP://$domain")
$searcher.Filter = "(objectClass=user)"
$results = $searcher.FindAll()

# Display results
$results | ForEach-Object {
    $_.Properties["samaccountname"]
}
```

### Test LDAPS (Secure LDAP)
```powershell
# Test LDAPS connection
$ldaps = New-Object DirectoryServices.DirectoryEntry("LDAPS://dc01.contoso.local")
try {
    $name = $ldaps.name
    Write-Host "LDAPS connection successful"
} catch {
    Write-Host "LDAPS connection failed: $_"
}
```

## Step 4: Configure LDAP Client Access

### Windows Clients
1. Install RSAT Tools for LDAP management:
```powershell
# Install RSAT tools
Install-WindowsFeature RSAT-AD-Tools
```

2. Configure LDAP client:
```powershell
# Example PowerShell LDAP query
$ldapConnection = New-Object System.DirectoryServices.DirectoryEntry("LDAP://dc01.contoso.local", "username", "password")
```

### Linux Clients
1. Install OpenLDAP client tools:
```bash
# Ubuntu/Debian
sudo apt-get install ldap-utils

# RHEL/CentOS
sudo yum install openldap-clients
```

2. Test LDAP connection:
```bash
# Test LDAP search
ldapsearch -H ldap://dc01.contoso.local:389 -D "CN=username,DC=contoso,DC=local" -w password -b "DC=contoso,DC=local"

# Test LDAPS search
ldapsearch -H ldaps://dc01.contoso.local:636 -D "CN=username,DC=contoso,DC=local" -w password -b "DC=contoso,DC=local"
```

## Step 5: LDAP Security Best Practices

1. Enable LDAP Signing
```powershell
# Configure LDAP signing
$policy = Get-ADDomainController
Set-ADDomainController -Identity $policy.HostName -LDAPServerIntegrity Required
```

2. Disable LDAP Anonymous Binding
```powershell
# Disable anonymous LDAP binding
$null = New-ItemProperty -Path "HKLM:\System\CurrentControlSet\Services\NTDS\Parameters" -Name "LDAPServerIntegrity" -Value 2 -PropertyType "DWord" -Force
```

3. Configure LDAP Channel Binding
```powershell
# Enable LDAP Channel Binding
$null = New-ItemProperty -Path "HKLM:\System\CurrentControlSet\Services\NTDS\Parameters" -Name "LdapEnforceChannelBinding" -Value 2 -PropertyType "DWord" -Force
```

## Step 6: Monitoring and Troubleshooting

### Monitor LDAP Activity
```powershell
# Enable LDAP logging
$null = New-ItemProperty -Path "HKLM:\System\CurrentControlSet\Services\NTDS\Diagnostics" -Name "15 LDAP Interface Events" -Value 2 -PropertyType "DWord" -Force

# View LDAP events
Get-EventLog -LogName "Directory Service" | Where-Object {$_.EventID -eq 2889}
```

### Common Troubleshooting Commands
```powershell
# Test LDAP ports
Test-NetConnection -ComputerName dc01.contoso.local -Port 389
Test-NetConnection -ComputerName dc01.contoso.local -Port 636

# Check certificate
certutil -verify dc01.contoso.local

# Test LDAP binding
$domain = "contoso.local"
$username = "administrator"
$password = ConvertTo-SecureString "Password123" -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($username, $password)

try {
    $ldapConnection = New-Object DirectoryServices.DirectoryEntry("LDAP://$domain", $credential.UserName, $credential.GetNetworkCredential().Password)
    if ($ldapConnection.name -ne $null) {
        Write-Host "LDAP binding successful"
    }
} catch {
    Write-Host "LDAP binding failed: $_"
}
```

## Step 7: Performance Tuning

### Optimize LDAP Query Performance
```powershell
# Set LDAP query policies
Set-ADDomainController -Identity dc01 -LDAPServerLimits @{
    MaxPageSize=1000
    MaxActiveQueries=20
    MaxConnections=5000
}
```

### Monitor LDAP Performance
```powershell
# Get LDAP performance counters
Get-Counter -Counter "\NTDS\LDAP Searches/sec"
Get-Counter -Counter "\NTDS\LDAP Successful Binds/sec"
Get-Counter -Counter "\NTDS\LDAP Client Sessions"
```

## Common Issues and Solutions

1. **Certificate Issues**
   - Verify certificate is valid and trusted
   - Check certificate chain
   - Ensure DNS names match

2. **Connection Issues**
   - Check firewall rules (ports 389, 636)
   - Verify DNS resolution
   - Test basic connectivity

3. **Authentication Issues**
   - Verify user credentials
   - Check group memberships
   - Review security policies

4. **Performance Issues**
   - Monitor resource usage
   - Review LDAP query patterns
   - Optimize search bases
