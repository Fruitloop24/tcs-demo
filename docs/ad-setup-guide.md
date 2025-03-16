# Windows Active Directory Setup Guide

## Overview
This guide documents the process of setting up a Windows Active Directory environment with role-based access control using Azure VMs. The environment includes a domain controller with three different user types, each with appropriate permissions and restrictions.

## Infrastructure Setup

### Azure VM Creation via CLI

```bash
# Login to Azure
az login

# Create a resource group
az group create --name ADDemo --location eastus

# Create Windows Server 2022 VM with appropriate specs
az vm create \
  --resource-group ADDemo \
  --name WinDC01 \
  --image MicrosoftWindowsServer:WindowsServer:2022-Datacenter:latest \
  --size Standard_D4s_v3 \
  --admin-username azureadmin \
  --admin-password "YourStrongPassword123!" \
  --public-ip-sku Standard \
  --nsg-rule RDP

# Open RDP port
az vm open-port --resource-group ADDemo --name WinDC01 --port 3389

# Get the public IP
az vm show -d --resource-group ADDemo --name WinDC01 --query publicIps -o tsv
```

### Connect to VM
1. Use RDP or Azure Bastion to connect to the VM
2. Login with the azureadmin credentials

## Active Directory Setup

### Install Active Directory Domain Services

#### PowerShell Method
```powershell
# Install AD DS role
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

# Configure as domain controller
$securePassword = ConvertTo-SecureString "Password123!" -AsPlainText -Force
Install-ADDSForest `
  -DomainName "contoso.local" `
  -DomainNetbiosName "CONTOSO" `
  -SafeModeAdministratorPassword $securePassword `
  -InstallDns:$true `
  -Force:$true
```

#### GUI Method
1. Open Server Manager
2. Click "Add Roles and Features"
3. Select "Role-based or feature-based installation"
4. Select the server from the pool
5. Check "Active Directory Domain Services"
6. Continue through the wizard and install
7. After installation, click the notification flag and "Promote this server to a domain controller"
8. Choose "Add a new forest" and enter "contoso.local" as the domain name
9. Set the Directory Services Restore Mode password
10. Complete the promotion wizard

### Create Organizational Units (OUs)

#### PowerShell Method
```powershell
New-ADOrganizationalUnit -Name "Admins" -Path "DC=contoso,DC=local"
New-ADOrganizationalUnit -Name "IT" -Path "DC=contoso,DC=local"
New-ADOrganizationalUnit -Name "Employees" -Path "DC=contoso,DC=local"
```

#### GUI Method
1. Open "Active Directory Users and Computers"
2. Right-click on the domain (contoso.local)
3. Select New > Organizational Unit
4. Create the three OUs: Admins, IT, and Employees

### Create Groups

#### PowerShell Method
```powershell
New-ADGroup -Name "IT Staff" -GroupScope Global -Path "OU=IT,DC=contoso,DC=local"
```

#### GUI Method
1. In "Active Directory Users and Computers"
2. Navigate to OU=IT
3. Right-click > New > Group
4. Enter "IT Staff" as the name
5. Select "Global" for Group scope

### Create Users

#### PowerShell Method
```powershell
# Create Alice (Admin)
New-ADUser -Name "Alice Admin" -GivenName Alice -Surname Admin -SamAccountName alice -UserPrincipalName alice@contoso.local -Path "OU=Admins,DC=contoso,DC=local" -AccountPassword (ConvertTo-SecureString "Pass123!" -AsPlainText -Force) -Enabled $true

# Create Bob (IT Staff)
New-ADUser -Name "Bob IT" -GivenName Bob -Surname IT -SamAccountName bob -UserPrincipalName bob@contoso.local -Path "OU=IT,DC=contoso,DC=local" -AccountPassword (ConvertTo-SecureString "Pass123!" -AsPlainText -Force) -Enabled $true

# Create Charlie (Regular User)
New-ADUser -Name "Charlie User" -GivenName Charlie -Surname User -SamAccountName charlie -UserPrincipalName charlie@contoso.local -Path "OU=Employees,DC=contoso,DC=local" -AccountPassword (ConvertTo-SecureString "Pass123!" -AsPlainText -Force) -Enabled $true
```

#### GUI Method
1. In "Active Directory Users and Computers"
2. Navigate to the appropriate OU
3. Right-click > New > User
4. Fill in the user details
5. Set a password and mark "Password never expires"
6. Complete the wizard

### Assign Groups and Permissions

#### PowerShell Method
```powershell
# Add Alice to Domain Admins
Add-ADGroupMember -Identity "Domain Admins" -Members alice

# Add Bob to IT Staff
Add-ADGroupMember -Identity "IT Staff" -Members bob

# Grant Bob password reset rights for Employees
dsacls "OU=Employees,DC=contoso,DC=local" /G "CONTOSO\bob:RPWP;userPassword"
dsacls "OU=Employees,DC=contoso,DC=local" /G "CONTOSO\bob:RP;*"
```

#### GUI Method
For adding to groups:
1. Open user properties
2. Go to "Member Of" tab
3. Click "Add" and search for the group
4. Add and apply

For delegation:
1. In "Active Directory Users and Computers"
2. Right-click the Employees OU
3. Select "Delegate Control"
4. Add Bob and delegate "Reset user passwords and force password change at next logon"

## Group Policy Configuration

### Create GPOs

#### PowerShell Method
```powershell
# Create policies
New-GPO -Name "IT Staff Restrictions"
New-GPO -Name "Employee Restrictions"

# Link policies to OUs
New-GPLink -Name "IT Staff Restrictions" -Target "OU=IT,DC=contoso,DC=local"
New-GPLink -Name "Employee Restrictions" -Target "OU=Employees,DC=contoso,DC=local"
```

#### GUI Method
1. Open "Group Policy Management"
2. Expand the forest > Domains > contoso.local
3. Right-click on "Group Policy Objects" and select "New"
4. Create the two policies
5. To link: right-click on the OU and select "Link an Existing GPO"

### Configure Policy Settings

#### PowerShell Method for IT Staff Restrictions
```powershell
$gpo = Get-GPO -Name "IT Staff Restrictions"
# Prevent software installation
Set-GPRegistryValue -Name $gpo.DisplayName -Key "HKLM\Software\Policies\Microsoft\Windows\Installer" -ValueName "DisableMSI" -Type DWord -Value 1
```

#### PowerShell Method for Employee Restrictions
```powershell
$gpo = Get-GPO -Name "Employee Restrictions"
# Block Control Panel access
Set-GPRegistryValue -Name $gpo.DisplayName -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -ValueName "NoControlPanel" -Type DWord -Value 1
# Prevent running executables
Set-GPRegistryValue -Name $gpo.DisplayName -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -ValueName "DisallowRun" -Type DWord -Value 1
Set-GPRegistryValue -Name $gpo.DisplayName -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\DisallowRun" -ValueName "1" -Type String -Value "*.exe"
# Block USB storage
Set-GPRegistryValue -Name $gpo.DisplayName -Key "HKLM\Software\Policies\Microsoft\Windows\RemovableStorageDevices" -ValueName "Deny_All" -Type DWord -Value 1
```

#### GUI Method
1. In "Group Policy Management"
2. Right-click on the GPO and select "Edit"
3. Navigate to the appropriate section:
   - For software installation restrictions: Computer Configuration > Policies > Administrative Templates > Windows Components > Windows Installer
   - For Control Panel restrictions: User Configuration > Policies > Administrative Templates > Control Panel
   - For removable storage: Computer Configuration > Policies > Administrative Templates > System > Removable Storage Access

## Environment Overview

### Organizational Structure
- **Admins OU**: Contains administrative users with full domain privileges
- **IT OU**: Contains IT support staff with limited administrative capabilities
- **Employees OU**: Contains regular users with restricted permissions

### User Roles and Permissions

#### Alice (Administrator)
- Member of: Domain Admins
- Permissions: Full administrative control over the entire domain
- Use Case: System administration, security configuration, user management

#### Bob (IT Support)
- Member of: IT Staff
- Permissions:
  - Can reset passwords for Employees
  - Can view system information
  - Limited software installation capabilities
- Use Case: Help desk support, routine maintenance, user support

#### Charlie (Regular Employee)
- Restrictions:
  - Cannot access Control Panel
  - Cannot run executable files
  - Cannot use removable storage
- Use Case: Regular business operations with appropriate security limitations

### Policy Implementation Logic
The implementation follows the principle of least privilege:
1. Administrative users have full control but are limited in number
2. IT support has targeted permissions required for their role
3. Regular users have restrictions to prevent unauthorized system changes

This setup demonstrates a secure, role-based access control system that can be easily extended for more complex organizational structures.

## Verification and Testing
To verify the setup works correctly:
1. Log in as each user type
2. Attempt actions that should be allowed/restricted based on their role
3. Check Group Policy application with `gpresult /r` command
4. Verify password reset functionality for Bob on Charlie's account

## Cleanup (When No Longer Needed)
```bash
# Delete the resource group and all resources
az group delete --name ADDemo --yes
```