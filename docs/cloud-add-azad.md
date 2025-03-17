# Azure Active Directory (Azure AD) Setup Guide

## Overview
This guide provides a step-by-step walkthrough for setting up **Azure Active Directory (Azure AD)** and integrating it with **Windows and Linux virtual machines (VMs)**. It includes identity management, security best practices, and troubleshooting for enterprise cloud environments.

---

## **1. Setting Up Azure AD**

### **Step 1: Create an Azure AD Tenant**
1. **Go to the Azure Portal** → Search for **Azure Active Directory**.
2. Click **Create a tenant** → Select **Azure AD**.
3. Enter:
   - **Organization Name**: Your Company Name
   - **Domain Name**: `yourcompany.onmicrosoft.com`
   - **Country/Region**: Select your location
4. Click **Create** → Wait for deployment.

### **Step 2: Create Custom Domain & Verify**
1. **Go to Azure AD** → **Custom domain names** → Click **Add custom domain**.
2. Enter `yourcompany.com` (must own this domain).
3. Add **DNS TXT Record** provided by Azure.
4. Click **Verify**.

### **Step 3: Create User Accounts**
#### **Azure Portal Method:**
1. **Go to Azure AD** → **Users** → Click **New user**.
2. Enter **Username, Name, and Role**.
3. Choose **Password method** (Auto-generate or manual entry).
4. Click **Create**.

#### **PowerShell Method:**
```powershell
Connect-AzureAD
New-AzureADUser -DisplayName "John Doe" -UserPrincipalName "john.doe@yourcompany.com" -PasswordProfile @{Password="SecurePass123!"; ForceChangePasswordNextSignIn=$true} -AccountEnabled $true
```

---

## **2. Adding Virtual Machines (VMs) to Azure AD**

### **Step 1: Create an Azure VM**
1. **Go to Azure Portal** → **Virtual Machines** → **Create new VM**.
2. Select:
   - **Image**: Windows Server 2022 / Ubuntu 22.04 LTS
   - **Size**: Standard B2s (or higher for production use)
   - **Authentication Type**: Password/SSH
3. Click **Create** and deploy VM.

### **Step 2: Enable Azure AD Join for Windows VMs**
#### **Using Azure Portal:**
1. Go to **Azure AD** → **Devices** → **Device settings**.
2. Enable **Users may join devices to Azure AD**.
3. On the Windows VM:
   - Open **Settings** → **Accounts** → **Access work or school**.
   - Click **Connect** → Sign in with your **Azure AD credentials**.

#### **Using PowerShell:**
```powershell
# Join Windows VM to Azure AD
Add-Computer -DomainName "yourcompany.onmicrosoft.com" -Credential (Get-Credential) -Restart
```

### **Step 3: Enable Azure AD Login for Linux VMs**
#### **Install the Azure AD Extension (Ubuntu/Debian)**
```bash
sudo apt update && sudo apt install aad-login -y
```

#### **Enable AAD Authentication on VM**
```bash
az login
az vm extension set --publisher Microsoft.Azure.ActiveDirectory.LinuxSSH --name AADSSHLoginForLinux --resource-group MyResourceGroup --vm-name MyLinuxVM
```

#### **Log in using Azure AD Credentials**
```bash
ssh -l "yourname@yourcompany.com" linuxvm.public.ip
```

---

## **3. Configuring Role-Based Access Control (RBAC) for Azure AD**

### **Step 1: Assign Azure AD Roles**
1. **Go to Azure AD** → **Roles and Administrators**.
2. Select a role (e.g., **Global Administrator**, **User Administrator**).
3. Click **Assign** → Select a user → Click **Assign**.

### **Step 2: Assign Azure VM Access Using RBAC**
1. **Go to the VM in Azure Portal**.
2. Click **Access Control (IAM)** → **Add role assignment**.
3. Select **Virtual Machine Administrator Login** or **Virtual Machine User Login**.
4. Assign the role to an **Azure AD user**.

---

## **4. Enforcing Security Best Practices**

### **1. Enable Multi-Factor Authentication (MFA)**
1. **Go to Azure AD** → **Security** → **MFA**.
2. Enable MFA for all users.

### **2. Set Conditional Access Policies**
1. **Go to Azure AD** → **Security** → **Conditional Access**.
2. Create a policy to require MFA for Admins.

### **3. Restrict Guest Access**
```powershell
# Disable guest access
Set-AzureADTenantDetail -AllowGuestUserSignIn $false
```

### **4. Implement Privileged Identity Management (PIM)**
1. **Go to Azure AD** → **Identity Governance** → **Privileged Identity Management (PIM)**.
2. Enable just-in-time (JIT) access for admin roles.

---

## **5. Monitoring and Troubleshooting Azure AD**

### **1. Check Azure AD Sign-in Logs**
```powershell
Get-AzureADAuditSignInLogs -Top 10
```

### **2. Reset Azure AD User Password**
```powershell
Set-AzureADUserPassword -ObjectId "user@yourcompany.com" -Password "NewSecurePass!" -ForceChangePasswordNextSignIn $true
```

### **3. Test Azure AD Join Status**
#### **Windows VM:**
```powershell
dsregcmd /status
```
#### **Linux VM:**
```bash
az vm show --resource-group MyResourceGroup --name MyLinuxVM --query identity
```

---

## **6. Summary & Next Steps**
✅ **Azure AD Tenant Setup** - Created and verified domain.  
✅ **Windows & Linux VM Integration** - Enabled Azure AD authentication.  
✅ **Security Best Practices** - Implemented MFA, RBAC, and Conditional Access.  
✅ **Monitoring & Troubleshooting** - Configured sign-in logs and device status checks.  

This guide ensures **secure and efficient** Azure AD integration for cloud environments!
