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