# Windows Active Directory Setup Guide (On-Premises/VM)

## Prerequisites

### Hardware Requirements
- CPU: 4 cores minimum (2.0 GHz or faster)
- RAM: 16GB minimum
- Storage: 100GB minimum for OS drive
- Network: 1Gbps NIC

### Software Requirements
- Windows Server 2022 Standard/Datacenter ISO
- Virtualization software (if using VM):
  - VMware Workstation/Player
  - VirtualBox
  - Hyper-V

## Step 1: Initial Server Setup

### VM Creation (Skip if using physical hardware)
1. Create a new VM with the following settings:
   - Type: Windows Server 2022
   - Memory: 16GB
   - CPU: 4 cores
   - Network: Bridged Adapter (important for domain connectivity)
   - Storage: 100GB minimum

2. Mount the Windows Server 2022 ISO and install Windows Server
   - Choose "Windows Server 2022 Standard/Datacenter (Desktop Experience)"
   - Follow standard Windows installation steps

### Network Configuration
1. Set static IP address:
   ```powershell
   # Example configuration - adjust for your network
   New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress "192.168.1.10" -PrefixLength 24 -DefaultGateway "192.168.1.1"
   Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses "127.0.0.1"
   ```

2. Rename computer (optional but recommended):
   ```powershell
   Rename-Computer -NewName "DC01" -Restart
   ```

## Step 2: Active Directory Setup

### Install AD DS Role
#### PowerShell Method
```powershell
# Install AD DS role and management tools
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

# Configure as domain controller
$securePassword = ConvertTo-SecureString "YourStrongPassword123!" -AsPlainText -Force
Install-ADDSForest `
    -DomainName "contoso.local" `
    -DomainNetbiosName "CONTOSO" `
    -SafeModeAdministratorPassword $securePassword `
    -InstallDns:$true `
    -Force:$true

# Server will restart automatically
```

#### GUI Method
1. Open Server Manager
2. Click "Add Roles and Features"
3. Select "Role-based installation"
4. Select your server
5. Check "Active Directory Domain Services"
6. Install and wait for completion
7. Click the notification flag and select "Promote this server to a domain controller"
8. Choose "Add a new forest"
9. Enter your domain name (e.g., "contoso.local")
10. Set DSRM password
11. Complete the wizard and allow restart

## Step 3: Post-Installation Configuration

### Create Organizational Units (OUs)
```powershell
# Create main OUs
$OUs = @("Admins", "IT", "Employees", "Computers", "Groups", "Service Accounts")
foreach ($OU in $OUs) {
    New-ADOrganizationalUnit -Name $OU -Path "DC=contoso,DC=local" -ProtectedFromAccidentalDeletion $true
}
```

### Create and Configure Groups
```powershell
# Create groups
$Groups = @{
    "IT Admins" = "OU=Groups,DC=contoso,DC=local"
    "Help Desk" = "OU=Groups,DC=contoso,DC=local"
    "Regular Users" = "OU=Groups,DC=contoso,DC=local"
}

foreach ($Group in $Groups.Keys) {
    New-ADGroup -Name $Group -GroupScope Global -Path $Groups[$Group]
}
```

### Create Test Users
```powershell
# Function to create user
function New-DemoUser {
    param(
        [string]$Name,
        [string]$Username,
        [string]$Path,
        [string[]]$Groups
    )
    
    $securePassword = ConvertTo-SecureString "Welcome123!" -AsPlainText -Force
    
    New-ADUser -Name $Name `
        -SamAccountName $Username `
        -UserPrincipalName "$Username@contoso.local" `
        -Path $Path `
        -AccountPassword $securePassword `
        -Enabled $true `
        -PasswordNeverExpires $true `
        -ChangePasswordAtLogon $false
    
    foreach ($Group in $Groups) {
        Add-ADGroupMember -Identity $Group -Members $Username
    }
}

# Create sample users
New-DemoUser -Name "John Admin" -Username "jadmin" -Path "OU=Admins,DC=contoso,DC=local" -Groups @("Domain Admins", "IT Admins")
New-DemoUser -Name "Sarah Help" -Username "shelp" -Path "OU=IT,DC=contoso,DC=local" -Groups @("Help Desk")
New-DemoUser -Name "Bob User" -Username "buser" -Path "OU=Employees,DC=contoso,DC=local" -Groups @("Regular Users")
```

## Step 4: Group Policy Configuration

### Create and Link GPOs
```powershell
# Create GPOs
$GPOs = @{
    "Security Baseline" = "DC=contoso,DC=local"
    "IT Restrictions" = "OU=IT,DC=contoso,DC=local"
    "User Restrictions" = "OU=Employees,DC=contoso,DC=local"
}

foreach ($GPO in $GPOs.Keys) {
    New-GPO -Name $GPO | New-GPLink -Target $GPOs[$GPO]
}
```

## Step 5: DNS Configuration

### Verify DNS Settings
```powershell
# Verify DNS is working
Get-DnsServerZone
Get-DnsServerForwarder

# Add forwarders if needed (example using Google DNS)
Add-DnsServerForwarder -IPAddress 8.8.8.8, 8.8.4.4
```

## Step 6: Verify Setup

### Check Domain Controller Status
```powershell
# Verify AD DS services
dcdiag /v

# Check replication status (for multiple DCs)
repadmin /showrepl

# Verify DNS
nslookup contoso.local
```

## Joining Computers to the Domain

### For Windows 10/11 Professional or Enterprise:

1. Set the computer's DNS to point to your domain controller:
   ```powershell
   Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses "192.168.1.10"
   ```

2. Join the domain (PowerShell as Administrator):
   ```powershell
   Add-Computer -DomainName "contoso.local" -Restart
   ```

   Or using GUI:
   1. Open System Properties (Win + Pause/Break)
   2. Click "Change settings" under Computer name
   3. Click "Change"
   4. Select "Domain" and enter "contoso.local"
   5. Enter domain admin credentials when prompted
   6. Restart the computer

### Troubleshooting Domain Join Issues

1. Verify network connectivity:
   ```powershell
   Test-NetConnection -ComputerName DC01 -Port 389
   ```

2. Verify DNS resolution:
   ```powershell
   nslookup contoso.local
   nslookup DC01.contoso.local
   ```

3. Check time synchronization:
   ```powershell
   w32tm /query /status
   ```

4. Common fixes:
   - Ensure client DNS points to DC
   - Verify firewall allows AD ports (see Step 1)
   - Sync time with DC
   - Clear DNS cache: `ipconfig /flushdns`

## Security Best Practices

1. Change default passwords
2. Enable Windows Firewall
3. Keep Windows updated
4. Implement LAPS (Local Administrator Password Solution)
5. Regular backup of System State
6. Monitor Event Logs
7. Implement password policies

## Backup and Recovery

### System State Backup
```powershell
wbadmin start systemstatebackup -backupTarget:E:
```

### Create System State Backup Task
```powershell
$action = New-ScheduledTaskAction -Execute 'wbadmin' -Argument 'start systemstatebackup -backupTarget:E:'
$trigger = New-ScheduledTaskTrigger -Daily -At 3AM
Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "AD Backup" -Description "Daily System State Backup"
```

## Monitoring and Maintenance

### Create Health Check Script
```powershell
# Save as C:\Scripts\AD-HealthCheck.ps1
$checks = @{
    "AD DS Service" = {(Get-Service NTDS).Status -eq "Running"}
    "DNS Service" = {(Get-Service DNS).Status -eq "Running"}
    "File System" = {(Get-PSDrive C).Free -gt 10GB}
    "DCDiag" = {(dcdiag /test:services /test:replications).Contains("passed test")}
}

$results = foreach ($check in $checks.Keys) {
    [PSCustomObject]@{
        Check = $check
        Status = if (& $checks[$check]) {"Healthy"} else {"Error"}
        Time = Get-Date
    }
}

$results | Export-Csv -Path "C:\Logs\AD-Health-$(Get-Date -Format 'yyyyMMdd').csv" -NoTypeInformation