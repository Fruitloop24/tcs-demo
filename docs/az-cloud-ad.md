# Cloud Active Directory & LDAP Setup Guide

## Overview
This guide covers setting up Active Directory and LDAP in a **cloud-based environment** using **Azure AD DS** and integrating it with Linux clients. It includes security best practices, hybrid identity management, and troubleshooting tips.

---

## **1. Setting Up Azure Active Directory Domain Services (Azure AD DS)**

### **Prerequisites**
- An **Azure subscription**
- A configured **Azure Virtual Network (VNet)**
- An **Azure AD tenant**

### **Step 1: Create an Azure AD DS Managed Domain**
1. **Go to the Azure portal** → **Create a resource** → Search for **Azure AD DS**.
2. Click **Create** and configure:
   - **Resource Group**: `AD-ResourceGroup`
   - **Domain Name**: `yourdomain.com`
   - **SKU**: `Standard` or `Enterprise`
3. Select the **VNet and Subnet** where domain-joined VMs will exist.
4. Enable **Secure LDAP (LDAPS)** and configure **certificate-based authentication** (optional but recommended).
5. Click **Review + Create** → Deploy **(Takes 30-60 mins)**.

### **Step 2: Configure Azure AD DS for Windows Authentication**
Once deployed:
1. Go to **Azure AD DS** → **Properties** → Copy the **DNS addresses**.
2. Update your **VNet DNS settings** to use **Azure AD DS IPs**.

### **Step 3: Join an Azure VM to the Domain**
#### **Windows VM**
```powershell
# Set DNS to point to Azure AD DS
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses "10.0.0.4"

# Join the domain
dism /online /enable-feature /featurename:NetFx3 /all
Add-Computer -DomainName "yourdomain.com" -Restart
```

#### **Linux VM (Ubuntu/Debian)**
```bash
# Install required packages
sudo apt update && sudo apt install realmd sssd sssd-tools adcli -y

# Join domain
sudo realm join yourdomain.com -U "admin@yourdomain.com" --install=/
```

---

## **2. Configuring LDAP Authentication with Azure AD DS**

### **Step 1: Enable Secure LDAP (LDAPS) in Azure AD DS**
1. In **Azure AD DS**, enable **LDAPS** under **Secure LDAP** settings.
2. Upload a valid **SSL certificate**.
3. Open **TCP ports 389 (LDAP) & 636 (LDAPS)** for **internal network traffic**.

### **Step 2: Test LDAP Connectivity (Windows & Linux)**
#### **Windows (PowerShell)**
```powershell
# Test LDAP over port 389
Test-NetConnection -ComputerName "yourdomain.com" -Port 389

# Test LDAPS over port 636
Test-NetConnection -ComputerName "yourdomain.com" -Port 636
```

#### **Linux (LDAP Search Query)**
```bash
# Test LDAP search (unsecure)
ldapsearch -H ldap://yourdomain.com -x -b "dc=yourdomain,dc=com"

# Test LDAPS search
ldapsearch -H ldaps://yourdomain.com -x -b "dc=yourdomain,dc=com"
```

### **Step 3: Configure Linux Authentication via LDAP**
1. Install LDAP utilities:
```bash
sudo apt install libnss-ldap libpam-ldap ldap-utils -y
```

2. Configure **LDAP client settings**:
```bash
sudo nano /etc/ldap/ldap.conf
```
Modify settings:
```
BASE dc=yourdomain,dc=com
URI ldap://yourdomain.com
TLS_CACERT /etc/ssl/certs/ca-certificates.crt
```

3. Restart services:
```bash
sudo systemctl restart nslcd
sudo systemctl restart sssd
```

---

## **3. Security Best Practices for Cloud-Based AD & LDAP**
### **1. Implement Multi-Factor Authentication (MFA)**
- Enforce **Azure AD Conditional Access Policies**.
- Require MFA for all **domain administrator accounts**.

### **2. Secure LDAP (LDAPS) Encryption**
- Always enable **LDAPS** and **disable plain LDAP**.
- Use **TLS 1.2+** for secure connections.

### **3. Restrict Access to AD DS & LDAP**
- Use **NSGs (Network Security Groups)** to allow **only necessary traffic**.
- Restrict domain join access to specific **subnets and security groups**.

### **4. Regular Auditing & Monitoring**
- Enable **Azure AD DS audit logs**.
- Monitor domain activity with **Azure Security Center**.

---

## **4. Troubleshooting AD & LDAP Issues in Azure**

### **1. Verify DNS Resolution**
```bash
nslookup yourdomain.com
```

### **2. Test Connectivity to LDAP Server**
```bash
ldapsearch -H ldaps://yourdomain.com -x -b "dc=yourdomain,dc=com"
```

### **3. Sync Time with Domain Controller (NTP Issues)**
```bash
sudo timedatectl set-ntp on
```

### **4. Check AD DS Replication Issues**
```powershell
dcdiag /v
repadmin /showrepl
```

### **5. Reset AD DS Connection & Restart LDAP Services**
```bash
sudo systemctl restart sssd
```

---

## **5. Summary & Final Thoughts**
- **Use Azure AD DS** for cloud-based Active Directory.
- **Enable Secure LDAP (LDAPS)** and use encryption.
- **Test connections** regularly to ensure authentication is working.
- **Monitor logs** and **audit access** for security.

This guide ensures a **secure, scalable, and cloud-ready** AD/LDAP setup for both Windows and Linux environments.
