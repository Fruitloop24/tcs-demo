# Complete AD Setup Script
# Save as "Setup-CompleteAD.ps1"

# Install AD DS and DNS
Install-WindowsFeature -Name AD-Domain-Services, DNS -IncludeManagementTools

# Create new forest and domain
$domainName = "contoso.local"
$netbiosName = "CONTOSO"
$safeModeAdminPassword = ConvertTo-SecureString "StrongPassword123!" -AsPlainText -Force

Install-ADDSForest `
    -DomainName $domainName `
    -DomainNetbiosName $netbiosName `
    -SafeModeAdministratorPassword $safeModeAdminPassword `
    -InstallDns:$true `
    -NoRebootOnCompletion:$false `
    -Force:$true

# After reboot, run CreateOUs-Users-Groups.ps1