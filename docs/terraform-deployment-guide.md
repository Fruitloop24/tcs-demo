# Automated Active Directory Deployment with Terraform

This guide demonstrates the deployment of a fully configured Windows Active Directory environment in Azure using Infrastructure as Code (IaC) with Terraform and PowerShell.

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Project Structure](#project-structure)
4. [Terraform Infrastructure Code](#terraform-infrastructure-code)
5. [PowerShell Configuration Script](#powershell-configuration-script)
6. [Deployment Process](#deployment-process)
7. [Verification](#verification)
8. [Security Considerations](#security-considerations)
9. [Cleanup](#cleanup)

## Overview

This project automates the deployment of a Windows Server with Active Directory Domain Services, complete with:
- A proper OU structure
- Role-based user accounts
- Security groups
- Group Policy Objects (GPOs) with security restrictions

This automation provides several advantages over manual configuration:
- **Consistency**: The environment is identical every time it's deployed
- **Time efficiency**: Deployment is completed in minutes rather than hours
- **Documentation**: The code serves as self-documenting infrastructure
- **Version control**: Changes can be tracked through Git
- **Scalability**: The approach can be extended to larger environments

## Prerequisites

- An Azure account with sufficient permissions
- Terraform installed (version 1.0.0+)
- Azure CLI installed and authenticated
- Basic understanding of Azure, Terraform, PowerShell, and Active Directory

### Terraform Installation Options

#### Option 1: Direct Installation

**On Windows:**
1. Download the Terraform binary from [Terraform's website](https://www.terraform.io/downloads.html)
2. Extract the zip file to a directory (e.g., `C:\terraform`)
3. Add that directory to your system's PATH environment variable
4. Verify installation by opening Command Prompt or PowerShell and typing:
   ```
   terraform -v
   ```

**On Linux (Ubuntu/Debian):**
```bash
sudo apt-get update
sudo apt-get install -y gnupg software-properties-common curl
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update
sudo apt-get install terraform
```

**On macOS:**
```bash
brew install terraform
```

#### Option 2: Using VS Code with Azure Extensions

Visual Studio Code offers excellent support for Terraform and Azure, providing a more integrated development experience:

1. **Install VS Code** from [code.visualstudio.com](https://code.visualstudio.com/)

2. **Install Required Extensions:**
   - HashiCorp Terraform (provides syntax highlighting, validation, and IntelliSense)
   - Azure Terraform (integrates with Azure)
   - Azure Account (for Azure authentication)

3. **Configure VS Code for Terraform:**
   - Enable format on save
   - Set up linting
   - Configure Azure authentication

4. **Benefits of Using VS Code:**
   - Syntax highlighting for Terraform files
   - Auto-completion for Azure resources and properties
   - Built-in terminal for running Terraform commands
   - Integration with Azure for resource browsing
   - Git integration for version control

5. **Workflow with VS Code:**
   - Create a new project folder
   - Initialize a git repository
   - Create Terraform files
   - Authenticate to Azure via Azure Account extension
   - Run Terraform commands from the integrated terminal
   - Commit changes to version control

## Project Structure

```
ad-deployment/
├── main.tf                  # Terraform infrastructure configuration
├── variables.tf             # Optional: Variable definitions
├── outputs.tf               # Optional: Output definitions
└── scripts/
    └── configure-ad.ps1     # PowerShell script for AD configuration
```

## Terraform Infrastructure Code

The `main.tf` file defines all Azure resources needed for the AD environment:

```hcl
# main.tf - Terraform script for Windows Active Directory Deployment

# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Create a resource group
resource "azurerm_resource_group" "ad_demo" {
  name     = "ADDemo"
  location = "eastus"
}

# Create a virtual network
resource "azurerm_virtual_network" "ad_vnet" {
  name                = "ad-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.ad_demo.location
  resource_group_name = azurerm_resource_group.ad_demo.name
}

# Create a subnet
resource "azurerm_subnet" "ad_subnet" {
  name                 = "ad-subnet"
  resource_group_name  = azurerm_resource_group.ad_demo.name
  virtual_network_name = azurerm_virtual_network.ad_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create a public IP address
resource "azurerm_public_ip" "ad_public_ip" {
  name                = "ad-public-ip"
  location            = azurerm_resource_group.ad_demo.location
  resource_group_name = azurerm_resource_group.ad_demo.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Create a network security group
resource "azurerm_network_security_group" "ad_nsg" {
  name                = "ad-nsg"
  location            = azurerm_resource_group.ad_demo.location
  resource_group_name = azurerm_resource_group.ad_demo.name

  security_rule {
    name                       = "RDP"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Create a network interface
resource "azurerm_network_interface" "ad_nic" {
  name                = "ad-nic"
  location            = azurerm_resource_group.ad_demo.location
  resource_group_name = azurerm_resource_group.ad_demo.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.ad_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ad_public_ip.id
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "ad_nic_nsg_assoc" {
  network_interface_id      = azurerm_network_interface.ad_nic.id
  network_security_group_id = azurerm_network_security_group.ad_nsg.id
}

# Create virtual machine
resource "azurerm_windows_virtual_machine" "ad_server" {
  name                = "WinDC01"
  resource_group_name = azurerm_resource_group.ad_demo.name
  location            = azurerm_resource_group.ad_demo.location
  size                = "Standard_D4s_v3"
  admin_username      = "azureadmin"
  admin_password      = "YourStrongPassword123!" # Change this in production
  network_interface_ids = [
    azurerm_network_interface.ad_nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }
}

# Custom script extension to install AD DS and configure domain
resource "azurerm_virtual_machine_extension" "ad_setup" {
  name                 = "ad-setup"
  virtual_machine_id   = azurerm_windows_virtual_machine.ad_server.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  protected_settings = <<SETTINGS
  {
    "commandToExecute": "powershell -command \"[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('${base64encode(file("${path.module}/scripts/configure-ad.ps1"))}')) | Out-File -filepath configure-ad.ps1\" && powershell -ExecutionPolicy Unrestricted -File configure-ad.ps1"
  }
  SETTINGS

  depends_on = [
    azurerm_windows_virtual_machine.ad_server
  ]
}

# Output the public IP address
output "ad_server_public_ip" {
  value = azurerm_public_ip.ad_public_ip.ip_address
}
```

### Key Components Explained:

1. **Provider Configuration**: Sets up the Azure provider for Terraform
2. **Resource Group**: Logical container for all Azure resources
3. **Networking Components**: VNet, subnet, public IP, NSG, and NIC for connectivity
4. **Virtual Machine**: Windows Server 2022 with proper sizing
5. **Custom Script Extension**: Executes the PowerShell script to configure AD

## PowerShell Configuration Script

The `configure-ad.ps1` script handles all the Active Directory configuration:

```powershell
# configure-ad.ps1
# PowerShell script to configure Active Directory Domain Services

# Function to write log entries
function Write-Log {
    param(
        [string]$Message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] $Message"
    Add-Content -Path "C:\Windows\Temp\ad-setup.log" -Value "[$timestamp] $Message"
}

Write-Log "Starting Active Directory setup script"

# Install AD DS role
try {
    Write-Log "Installing Active Directory Domain Services role"
    Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
    Write-Log "AD DS role installation completed"
} catch {
    Write-Log "Error installing AD DS role: $_"
    Exit 1
}

# Create a secure string for the administrator password
$safeModePwd = ConvertTo-SecureString "Password123!" -AsPlainText -Force

# Configure the domain
try {
    Write-Log "Configuring domain controller"
    Install-ADDSForest `
        -DomainName "contoso.local" `
        -DomainNetbiosName "CONTOSO" `
        -SafeModeAdministratorPassword $safeModePwd `
        -InstallDns:$true `
        -Force:$true
    Write-Log "Domain controller configuration initiated"
} catch {
    Write-Log "Error configuring domain controller: $_"
    Exit 1
}

# Note: The server will reboot after AD DS installation
# The following commands will execute after reboot via a scheduled task

# Create a script for post-reboot configuration
$postRebootScript = @'
# Post-reboot AD configuration script

# Function to write log entries
function Write-Log {
    param(
        [string]$Message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] $Message"
    Add-Content -Path "C:\Windows\Temp\ad-post-reboot.log" -Value "[$timestamp] $Message"
}

Write-Log "Starting post-reboot configuration"

# Create Organizational Units
try {
    Write-Log "Creating Organizational Units"
    New-ADOrganizationalUnit -Name "Admins" -Path "DC=contoso,DC=local"
    New-ADOrganizationalUnit -Name "IT" -Path "DC=contoso,DC=local"
    New-ADOrganizationalUnit -Name "Employees" -Path "DC=contoso,DC=local"
    Write-Log "OU creation completed"
} catch {
    Write-Log "Error creating OUs: $_"
}

# Create IT Staff group
try {
    Write-Log "Creating IT Staff group"
    New-ADGroup -Name "IT Staff" -GroupScope Global -Path "OU=IT,DC=contoso,DC=local"
    Write-Log "Group creation completed"
} catch {
    Write-Log "Error creating groups: $_"
}

# Create users
try {
    Write-Log "Creating users"
    
    # Create Alice (Admin)
    New-ADUser -Name "Alice Admin" -GivenName Alice -Surname Admin `
        -SamAccountName alice -UserPrincipalName alice@contoso.local `
        -Path "OU=Admins,DC=contoso,DC=local" `
        -AccountPassword (ConvertTo-SecureString "Pass123!" -AsPlainText -Force) `
        -Enabled $true -PasswordNeverExpires $true
    
    # Create Bob (IT Staff)
    New-ADUser -Name "Bob IT" -GivenName Bob -Surname IT `
        -SamAccountName bob -UserPrincipalName bob@contoso.local `
        -Path "OU=IT,DC=contoso,DC=local" `
        -AccountPassword (ConvertTo-SecureString "Pass123!" -AsPlainText -Force) `
        -Enabled $true -PasswordNeverExpires $true
    
    # Create Charlie (Regular User)
    New-ADUser -Name "Charlie User" -GivenName Charlie -Surname User `
        -SamAccountName charlie -UserPrincipalName charlie@contoso.local `
        -Path "OU=Employees,DC=contoso,DC=local" `
        -AccountPassword (ConvertTo-SecureString "Pass123!" -AsPlainText -Force) `
        -Enabled $true -PasswordNeverExpires $true
    
    Write-Log "User creation completed"
} catch {
    Write-Log "Error creating users: $_"
}

# Assign group memberships
try {
    Write-Log "Assigning group memberships"
    
    # Add Alice to Domain Admins
    Add-ADGroupMember -Identity "Domain Admins" -Members alice
    
    # Add Bob to IT Staff
    Add-ADGroupMember -Identity "IT Staff" -Members bob
    
    Write-Log "Group membership assignment completed"
} catch {
    Write-Log "Error assigning group memberships: $_"
}

# Configure permission delegation
try {
    Write-Log "Configuring permission delegation"
    
    # Grant Bob password reset rights for Employees
    dsacls "OU=Employees,DC=contoso,DC=local" /G "CONTOSO\bob:RPWP;userPassword"
    dsacls "OU=Employees,DC=contoso,DC=local" /G "CONTOSO\bob:RP;*"
    
    Write-Log "Permission delegation completed"
} catch {
    Write-Log "Error configuring permission delegation: $_"
}

# Create and configure Group Policies
try {
    Write-Log "Creating Group Policies"
    
    # Create policies
    New-GPO -Name "IT Staff Restrictions"
    New-GPO -Name "Employee Restrictions"
    
    # Link policies to OUs
    New-GPLink -Name "IT Staff Restrictions" -Target "OU=IT,DC=contoso,DC=local"
    New-GPLink -Name "Employee Restrictions" -Target "OU=Employees,DC=contoso,DC=local"
    
    Write-Log "Group Policy creation completed"
} catch {
    Write-Log "Error creating Group Policies: $_"
}

# Configure IT Staff policy
try {
    Write-Log "Configuring IT Staff policy"
    
    $gpo = Get-GPO -Name "IT Staff Restrictions"
    # Prevent software installation
    Set-GPRegistryValue -Name $gpo.DisplayName `
        -Key "HKLM\Software\Policies\Microsoft\Windows\Installer" `
        -ValueName "DisableMSI" -Type DWord -Value 1
    
    Write-Log "IT Staff policy configuration completed"
} catch {
    Write-Log "Error configuring IT Staff policy: $_"
}

# Configure Employee policy
try {
    Write-Log "Configuring Employee policy"
    
    $gpo = Get-GPO -Name "Employee Restrictions"
    
    # Block Control Panel access
    Set-GPRegistryValue -Name $gpo.DisplayName `
        -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" `
        -ValueName "NoControlPanel" -Type DWord -Value 1
    
    # Prevent running executables
    Set-GPRegistryValue -Name $gpo.DisplayName `
        -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" `
        -ValueName "DisallowRun" -Type DWord -Value 1
    
    Set-GPRegistryValue -Name $gpo.DisplayName `
        -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\DisallowRun" `
        -ValueName "1" -Type String -Value "*.exe"
    
    # Block USB storage
    Set-GPRegistryValue -Name $gpo.DisplayName `
        -Key "HKLM\Software\Policies\Microsoft\Windows\RemovableStorageDevices" `
        -ValueName "Deny_All" -Type DWord -Value 1
    
    Write-Log "Employee policy configuration completed"
} catch {
    Write-Log "Error configuring Employee policy: $_"
}

Write-Log "Post-reboot configuration completed"

# Remove the scheduled task
Unregister-ScheduledTask -TaskName "ADPostConfig" -Confirm:$false

Write-Log "Scheduled task removed. Active Directory setup is complete."
'@

# Save the post-reboot script
$postRebootScript | Out-File -FilePath "C:\Windows\Temp\post-reboot-config.ps1" -Encoding UTF8

# Create a scheduled task to run the post-reboot script
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -File C:\Windows\Temp\post-reboot-config.ps1"
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName "ADPostConfig" -Action $action -Trigger $trigger -Principal $principal -Description "Configure AD after reboot"

Write-Log "Scheduled post-reboot configuration task created"
Write-Log "Initial AD setup script completed. Server will reboot."
```

### Script Breakdown:

1. **First Stage (Before Reboot)**:
   - Installs AD DS role
   - Configures the domain
   - Creates a scheduled task for post-reboot configuration

2. **Second Stage (After Reboot)**:
   - Creates Organizational Units (OUs)
   - Creates groups
   - Creates user accounts with the appropriate permissions
   - Configures group memberships
   - Sets up delegated permissions
   - Creates and configures Group Policy Objects (GPOs)

3. **Advanced Features**:
   - Comprehensive error handling
   - Detailed logging
   - Persistence across reboots
   - Automated cleanup of temporary assets

## Deployment Process

### Command Line Deployment

Follow these steps to deploy the Active Directory environment using the command line:

1. **Prepare the project directory**:
   ```bash
   mkdir ad-deployment
   cd ad-deployment
   mkdir scripts
   ```

2. **Create the files**:
   - Create `main.tf` with the Terraform code
   - Create `scripts/configure-ad.ps1` with the PowerShell code

3. **Initialize Terraform**:
   ```bash
   terraform init
   ```

4. **Authenticate with Azure**:
   ```bash
   az login
   ```

5. **Preview the deployment**:
   ```bash
   terraform plan
   ```

6. **Deploy the infrastructure**:
   ```bash
   terraform apply
   ```
   When prompted, type "yes" to confirm.

7. **Monitor the deployment**:
   Terraform will provide status updates as resources are created. The entire process typically takes 15-20 minutes, with most of the time spent on the Active Directory installation and configuration.

8. **Get the VM IP address**:
   ```bash
   terraform output ad_server_public_ip
   ```

### VS Code Deployment

Using Visual Studio Code provides a more integrated experience:

1. **Open the project in VS Code**:
   - Create a new folder for your project
   - Open VS Code and select "Open Folder"
   - Create the `main.tf` and `scripts/configure-ad.ps1` files

2. **Use VS Code's integrated terminal**:
   - Open the terminal with `` Ctrl+` ``
   - All Terraform commands can be run from this terminal

3. **Authentication with Azure Extensions**:
   - Click on the Azure icon in the sidebar
   - Sign in to your Azure account
   - You'll see your subscriptions and resources

4. **Terraform with VS Code**:
   - The HashiCorp Terraform extension provides syntax highlighting and IntelliSense
   - Run `terraform init`, `terraform plan`, and `terraform apply` from the integrated terminal
   - The Azure Terraform extension provides additional integration with Azure resources

5. **Advantages of VS Code deployment**:
   - Real-time syntax validation
   - Code completion for Azure resources
   - Easy navigation between files
   - Git integration for version control
   - Integrated terminal for command execution
   - Azure resource visualization

## Verification

To verify your Active Directory setup works correctly:

1. **Connect to the VM**:
   - Use RDP to connect to the server using the provided public IP
   - Login with the azureadmin credentials

2. **Verify Active Directory Installation**:
   - Open Server Manager and check if AD DS role is installed
   - Use Active Directory Users and Computers to verify:
     - The OU structure (Admins, IT, Employees)
     - User accounts (Alice, Bob, Charlie)
     - Group memberships

3. **Test User Permissions**:
   - Login as Bob and try to reset Charlie's password
   - Login as Charlie and verify restrictions
   - Login as Alice and verify administrative capabilities

4. **Check Group Policy Application**:
   - Run `gpresult /r` as each user to verify policy application
   - Test the specific restrictions (Control Panel access, executable restrictions, USB access)

## Security Considerations

This deployment includes several security best practices, but for production environments, consider these additional measures:

1. **Password Management**:
   - Use Azure Key Vault for secure password storage
   - Implement more complex password policies
   - Don't hardcode passwords in scripts or Terraform files

2. **Network Security**:
   - Restrict RDP access to specific IP addresses
   - Implement Azure Bastion for secure VM access
   - Set up a VPN for access to the AD environment

3. **Monitoring and Logging**:
   - Enable Azure Security Center
   - Set up Azure Monitor for the VM
   - Configure Windows Event Forwarding

4. **Backup Strategy**:
   - Implement regular AD backups
   - Set up Azure Backup for the VM

## Cleanup

When you're done with the environment, clean up all resources to avoid unnecessary charges:

```bash
terraform destroy
```

When prompted, type "yes" to confirm the deletion of all resources.

## Conclusion

This Infrastructure as Code approach to Active Directory deployment demonstrates:

1. **Automation Expertise**: The ability to automate complex Windows infrastructure
2. **Security Knowledge**: Implementation of role-based access control
3. **Best Practices**: Proper error handling, logging, and persistence strategies
4. **DevOps Skills**: Integration of infrastructure provisioning with configuration management

This pattern can be extended to more complex scenarios including:
- Multi-DC environments
- Hybrid AD configurations with Azure AD
- Enterprise-scale domain structures with complex OU hierarchies and GPO implementations