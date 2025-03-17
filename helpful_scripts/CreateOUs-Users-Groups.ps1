# Create OUs, Users and Groups
# Save as "CreateOUs-Users-Groups.ps1"

# Create OUs
$OUs = @("Administrators", "IT Support", "Employees", "Shared Resources", "Computers")
foreach ($OU in $OUs) {
    New-ADOrganizationalUnit -Name $OU -Path "DC=contoso,DC=local" -ProtectedFromAccidentalDeletion $true
}

# Create Security Groups
$Groups = @{
    "Domain Admins" = "OU=Administrators,DC=contoso,DC=local"
    "IT Staff" = "OU=IT Support,DC=contoso,DC=local"
    "Regular Users" = "OU=Employees,DC=contoso,DC=local"
}

foreach ($Group in $Groups.Keys) {
    New-ADGroup -Name $Group -GroupScope Global -GroupCategory Security -Path $Groups[$Group]
}

# Create Users
$Users = @(
    @{
        Name = "Alice Admin"
        Username = "alice"
        Password = "P@ssw0rd123!"
        Path = "OU=Administrators,DC=contoso,DC=local"
        Groups = @("Domain Admins")
    },
    @{
        Name = "Bob Support"
        Username = "bob"
        Password = "P@ssw0rd123!"
        Path = "OU=IT Support,DC=contoso,DC=local"
        Groups = @("IT Staff")
    },
    @{
        Name = "Charlie User"
        Username = "charlie"
        Password = "P@ssw0rd123!"
        Path = "OU=Employees,DC=contoso,DC=local"
        Groups = @("Regular Users")
    }
)

foreach ($User in $Users) {
    $securePassword = ConvertTo-SecureString $User.Password -AsPlainText -Force
    
    New-ADUser `
        -Name $User.Name `
        -SamAccountName $User.Username `
        -UserPrincipalName "$($User.Username)@contoso.local" `
        -Path $User.Path `
        -AccountPassword $securePassword `
        -Enabled $true `
        -PasswordNeverExpires $true
    
    foreach ($Group in $User.Groups) {
        Add-ADGroupMember -Identity $Group -Members $User.Username
    }
}