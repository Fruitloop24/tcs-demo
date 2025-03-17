# Create and Link GPOs
# Save as "Setup-GroupPolicies.ps1"

# Create GPOs for different security levels
New-GPO -Name "Security - Administrators" | New-GPLink -Target "OU=Administrators,DC=contoso,DC=local"
New-GPO -Name "Security - IT Staff" | New-GPLink -Target "OU=IT Support,DC=contoso,DC=local"
New-GPO -Name "Security - Employees" | New-GPLink -Target "OU=Employees,DC=contoso,DC=local"

# Configure Employee restrictions (limited access)
$EmployeeGPO = Get-GPO -Name "Security - Employees"
Set-GPRegistryValue -Name $EmployeeGPO.DisplayName -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -ValueName "NoControlPanel" -Type DWord -Value 1
Set-GPRegistryValue -Name $EmployeeGPO.DisplayName -Key "HKCU\Software\Policies\Microsoft\Windows\System" -ValueName "DisableCMD" -Type DWord -Value 1

# Configure IT Staff (some admin capabilities)
$ITStaffGPO = Get-GPO -Name "Security - IT Staff"
Set-GPRegistryValue -Name $ITStaffGPO.DisplayName -Key "HKLM\Software\Policies\Microsoft\Windows\Installer" -ValueName "AlwaysInstallElevated" -Type DWord -Value 1