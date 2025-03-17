# LDAP and LDAPS Configuration Script
# Save as "Configure-LDAP-LDAPS.ps1"

# Step 1: Verify LDAP is running
$ldapPort = Test-NetConnection -ComputerName localhost -Port 389 -InformationLevel Quiet
Write-Host "LDAP on port 389: $(if ($ldapPort) {"Running"} else {"Not running"})"

# Step 2: Configure LDAPS Certificate
# Create a self-signed certificate for LDAPS
$serverFQDN = "$env:COMPUTERNAME.$((Get-WmiObject Win32_ComputerSystem).Domain)"
Write-Host "Creating certificate for $serverFQDN"

$certParams = @{
    DnsName = $serverFQDN
    CertStoreLocation = "cert:\LocalMachine\My"
    KeyAlgorithm = "RSA"
    KeyLength = 2048
    KeyExportPolicy = "Exportable"
    KeyUsage = "DigitalSignature", "KeyEncipherment"
    KeyUsageProperty = "Sign", "KeyEncipherment"
    Provider = "Microsoft RSA SChannel Cryptographic Provider"
    HashAlgorithm = "SHA256"
    NotAfter = (Get-Date).AddYears(5)
}

$certificate = New-SelfSignedCertificate @certParams
Write-Host "Certificate created with thumbprint: $($certificate.Thumbprint)"

# Export certificate for distribution
$certPassword = ConvertTo-SecureString -String "CertPassword123!" -Force -AsPlainText
Export-PfxCertificate -Cert $certificate -FilePath "$env:USERPROFILE\Desktop\LDAPSCert.pfx" -Password $certPassword
Export-Certificate -Cert $certificate -FilePath "$env:USERPROFILE\Desktop\LDAPSCert.cer" -Type CERT

# Step 3: Register the certificate for LDAPS
$certPath = "HKLM:\SYSTEM\CurrentControlSet\Services\NTDS\Parameters"
$ntdsParams = @{
    Path = $certPath
    Name = "LdapServerLDAPSCertificateMappings"
    Value = @($certificate.Thumbprint)
    PropertyType = "MultiString"
    Force = $true
}

if (!(Test-Path $certPath)) {
    New-Item -Path $certPath -Force | Out-Null
}

New-ItemProperty @ntdsParams
Write-Host "Certificate registered for LDAPS"

# Step 4: Configure LDAP Security Settings
# Set LDAP signing requirements
$ldapIntegrityParams = @{
    Path = "HKLM:\System\CurrentControlSet\Services\NTDS\Parameters"
    Name = "LDAPServerIntegrity"
    Value = 2  # 2 = Required
    PropertyType = "DWord"
    Force = $true
}
New-ItemProperty @ldapIntegrityParams
Write-Host "LDAP signing set to Required"

# Configure LDAP Channel Binding
$ldapChannelBindingParams = @{
    Path = "HKLM:\System\CurrentControlSet\Services\NTDS\Parameters"
    Name = "LdapEnforceChannelBinding"
    Value = 2  # 2 = Required
    PropertyType = "DWord"
    Force = $true
}
New-ItemProperty @ldapChannelBindingParams
Write-Host "LDAP Channel Binding set to Required"

# Step 5: Configure Firewall for LDAP and LDAPS
New-NetFirewallRule -DisplayName "LDAP 389" -Direction Inbound -Protocol TCP -LocalPort 389 -Action Allow
New-NetFirewallRule -DisplayName "LDAPS 636" -Direction Inbound -Protocol TCP -LocalPort 636 -Action Allow
Write-Host "Firewall rules added for LDAP and LDAPS"

# Step 6: Enable LDAP Diagnostics Logging
$diagParams = @{
    Path = "HKLM:\System\CurrentControlSet\Services\NTDS\Diagnostics"
    Name = "15 LDAP Interface Events"
    Value = 2  # 2 = Verbose logging
    PropertyType = "DWord"
    Force = $true
}
New-ItemProperty @diagParams
Write-Host "LDAP diagnostics logging enabled"

# Step 7: Restart Directory Services for changes to take effect
Write-Host "Restarting Directory Services..."
Restart-Service -Name NTDS -Force
Write-Host "Services restarted"

# Step 8: Test LDAPS Connection
Write-Host "Testing LDAPS connection..."
$domainName = (Get-WmiObject Win32_ComputerSystem).Domain
$domain = "DC=$($domainName.Replace(".", ",DC="))"

try {
    $ldapsConn = New-Object DirectoryServices.DirectoryEntry("LDAPS://$serverFQDN/$domain")
    Write-Host "LDAPS connection successful: $($ldapsConn.distinguishedName)"
} catch {
    Write-Host "LDAPS connection failed: $_"
    Write-Host "Note: It may take a few minutes for the certificate to be fully registered."
}

Write-Host "LDAP/LDAPS configuration completed!"