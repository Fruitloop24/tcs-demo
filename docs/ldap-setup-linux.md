# OpenLDAP Setup Guide for Linux

## Overview
This guide provides step-by-step instructions for setting up OpenLDAP on a Linux server. OpenLDAP is an open-source implementation of the Lightweight Directory Access Protocol that provides directory services similar to Microsoft Active Directory.

## Prerequisites
- Linux server (Ubuntu/Debian or RHEL/CentOS)
- Root or sudo access
- Basic understanding of LDAP concepts
- Properly configured DNS (FQDN for your server)

## Installation Steps

### Ubuntu/Debian Systems

1. **Update package repositories**:
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

2. **Install OpenLDAP and related utilities**:
   ```bash
   sudo apt install slapd ldap-utils -y
   ```
   During installation, you'll be prompted to set an administrator password for the LDAP directory.

3. **Reconfigure the LDAP server with proper domain settings**:
   ```bash
   sudo dpkg-reconfigure slapd
   ```
   
   You'll be asked several questions:
   - Omit OpenLDAP server configuration? **No**
   - DNS domain name: Enter your domain (e.g., `example.org`)
   - Organization name: Enter your organization name (e.g., `Example Inc`)
   - Administrator password: Create a strong password
   - Database backend: **MDB**
   - Remove the database when slapd is purged? **No**
   - Move old database? **Yes**

4. **Verify the installation**:
   ```bash
   sudo systemctl status slapd
   ```
   
   Ensure the service is active and running.

### RHEL/CentOS Systems

1. **Update package repositories**:
   ```bash
   sudo yum update -y
   ```

2. **Install OpenLDAP and related utilities**:
   ```bash
   sudo yum install openldap openldap-servers openldap-clients -y
   ```

3. **Start and enable the LDAP service**:
   ```bash
   sudo systemctl start slapd
   sudo systemctl enable slapd
   ```

4. **Set the admin password**:
   ```bash
   # Generate a hashed password
   LDAP_PASSWORD_HASH=$(slappasswd -s your_password_here)
   
   # Create a temporary LDIF file
   cat > chrootpw.ldif << EOF
   dn: olcDatabase={0}config,cn=config
   changetype: modify
   add: olcRootPW
   olcRootPW: $LDAP_PASSWORD_HASH
   EOF
   
   # Apply the changes
   sudo ldapadd -Y EXTERNAL -H ldapi:/// -f chrootpw.ldif
   ```

5. **Import the basic schemas**:
   ```bash
   sudo ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/cosine.ldif
   sudo ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/nis.ldif
   sudo ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/inetorgperson.ldif
   ```

6. **Configure your domain**:
   ```bash
   # Create a temporary LDIF file for domain configuration
   cat > basedomain.ldif << EOF
   dn: olcDatabase={1}monitor,cn=config
   changetype: modify
   replace: olcAccess
   olcAccess: {0}to * by dn.base="gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth" read by dn.base="cn=Manager,dc=example,dc=org" read by * none

   dn: olcDatabase={2}mdb,cn=config
   changetype: modify
   replace: olcSuffix
   olcSuffix: dc=example,dc=org

   dn: olcDatabase={2}mdb,cn=config
   changetype: modify
   replace: olcRootDN
   olcRootDN: cn=Manager,dc=example,dc=org

   dn: olcDatabase={2}mdb,cn=config
   changetype: modify
   replace: olcRootPW
   olcRootPW: $LDAP_PASSWORD_HASH
   EOF
   
   # Replace dc=example,dc=org with your domain in the file
   # Then apply the changes
   sudo ldapmodify -Y EXTERNAL -H ldapi:/// -f basedomain.ldif
   ```

## Basic Configuration

### Creating the Base Organizational Units (OUs)

1. **Create an LDIF file for your base structure**:
   ```bash
   cat > base_structure.ldif << EOF
   # Base DN
   dn: dc=example,dc=org
   objectClass: top
   objectClass: dcObject
   objectClass: organization
   o: Example Organization
   dc: example

   # Users OU
   dn: ou=Users,dc=example,dc=org
   objectClass: organizationalUnit
   ou: Users

   # Groups OU
   dn: ou=Groups,dc=example,dc=org
   objectClass: organizationalUnit
   ou: Groups

   # Computers OU
   dn: ou=Computers,dc=example,dc=org
   objectClass: organizationalUnit
   ou: Computers
   EOF
   ```
   Replace `dc=example,dc=org` with your domain components.

2. **Add the base structure to LDAP**:
   ```bash
   ldapadd -x -D cn=Manager,dc=example,dc=org -W -f base_structure.ldif
   ```
   You'll be prompted for the admin password.

### Creating User Accounts

1. **Create an LDIF file for a sample user**:
   ```bash
   cat > sample_user.ldif << EOF
   dn: uid=john,ou=Users,dc=example,dc=org
   objectClass: inetOrgPerson
   objectClass: posixAccount
   objectClass: shadowAccount
   uid: john
   sn: Doe
   givenName: John
   cn: John Doe
   displayName: John Doe
   uidNumber: 10000
   gidNumber: 10000
   userPassword: {SSHA}hashofyourpassword
   gecos: John Doe
   loginShell: /bin/bash
   homeDirectory: /home/john
   shadowExpire: -1
   shadowFlag: 0
   shadowWarning: 7
   shadowMin: 0
   shadowMax: 99999
   shadowLastChange: 18187
   mail: john.doe@example.org
   postalCode: 12345
   l: New York
   o: Example Company
   mobile: +1 123 456 7890
   homePhone: +1 234 567 8901
   title: System Administrator
   initials: JD
   EOF
   ```

2. **Generate an SSHA password hash to replace in the file**:
   ```bash
   slappasswd -s userpassword
   ```
   Replace `{SSHA}hashofyourpassword` with the generated hash.

3. **Add the user to LDAP**:
   ```bash
   ldapadd -x -D cn=Manager,dc=example,dc=org -W -f sample_user.ldif
   ```

## Enabling Security

### Configure LDAPS (LDAP over SSL/TLS)

1. **Create a self-signed certificate**:
   ```bash
   sudo mkdir -p /etc/openldap/certs
   
   sudo openssl req -new -x509 -nodes -out /etc/openldap/certs/ldap.crt \
     -keyout /etc/openldap/certs/ldap.key -days 365 \
     -subj "/CN=ldap.example.org"
   
   sudo chown -R ldap:ldap /etc/openldap/certs
   sudo chmod 600 /etc/openldap/certs/ldap.key
   ```

2. **Create LDIF file for TLS configuration**:
   ```bash
   cat > tls_config.ldif << EOF
   dn: cn=config
   changetype: modify
   add: olcTLSCACertificateFile
   olcTLSCACertificateFile: /etc/openldap/certs/ldap.crt
   -
   add: olcTLSCertificateFile
   olcTLSCertificateFile: /etc/openldap/certs/ldap.crt
   -
   add: olcTLSCertificateKeyFile
   olcTLSCertificateKeyFile: /etc/openldap/certs/ldap.key
   EOF
   ```

3. **Apply the TLS configuration**:
   ```bash
   sudo ldapmodify -Y EXTERNAL -H ldapi:/// -f tls_config.ldif
   ```

4. **Restart OpenLDAP**:
   ```bash
   sudo systemctl restart slapd
   ```

## Testing the Configuration

### Using ldapsearch to Verify Setup

1. **Test anonymous access**:
   ```bash
   ldapsearch -x -b "dc=example,dc=org" -H ldap://localhost
   ```

2. **Test authenticated access**:
   ```bash
   ldapsearch -x -D "cn=Manager,dc=example,dc=org" -W -b "dc=example,dc=org" -H ldap://localhost
   ```

3. **Test LDAPS connection**:
   ```bash
   ldapsearch -x -D "cn=Manager,dc=example,dc=org" -W -b "dc=example,dc=org" -H ldaps://localhost
   ```

## Enabling Client Access

### Configure PAM and NSS for LDAP Authentication

1. **Install required packages**:
   ```bash
   # Ubuntu/Debian
   sudo apt install libpam-ldap libnss-ldap -y
   
   # RHEL/CentOS
   sudo yum install nss-pam-ldapd -y
   ```

2. **Configure NSS**:
   Edit `/etc/nsswitch.conf`:
   ```
   passwd:     files ldap
   shadow:     files ldap
   group:      files ldap
   ```

3. **Configure PAM**:
   For Ubuntu/Debian, run:
   ```bash
   sudo pam-auth-update --enable ldap
   ```
   
   For RHEL/CentOS, run:
   ```bash
   authconfig --enableldap --enableldapauth --ldapserver=ldap://localhost --ldapbasedn="dc=example,dc=org" --update
   ```

## Managing LDAP with Web-Based Tools

### Install phpLDAPadmin for Web-Based Management

1. **Install web server and phpLDAPadmin**:
   ```bash
   # Ubuntu/Debian
   sudo apt install apache2 phpldapadmin -y
   
   # RHEL/CentOS
   sudo yum install httpd phpldapadmin -y
   ```

2. **Configure phpLDAPadmin**:
   Edit the configuration file:
   ```bash
   # Ubuntu/Debian
   sudo nano /etc/phpldapadmin/config.php
   
   # RHEL/CentOS
   sudo nano /etc/phpldapadmin/config.php
   ```
   
   Update these settings:
   ```php
   $servers->setValue('server','host','127.0.0.1');
   $servers->setValue('server','base',array('dc=example,dc=org'));
   $servers->setValue('login','bind_id','cn=Manager,dc=example,dc=org');
   ```

3. **Restart the web server**:
   ```bash
   # Ubuntu/Debian
   sudo systemctl restart apache2
   
   # RHEL/CentOS
   sudo systemctl restart httpd
   ```

4. **Access phpLDAPadmin**:
   Open a web browser and navigate to:
   ```
   http://your_server_ip/phpldapadmin
   ```

## Troubleshooting

### Common Issues and Solutions

1. **OpenLDAP service won't start**:
   ```bash
   # Check logs
   sudo journalctl -u slapd
   
   # Check configuration
   sudo slaptest -u
   ```

2. **Connection issues**:
   ```bash
   # Test if server is listening
   sudo netstat -tuln | grep 389
   
   # Check firewall settings
   sudo firewall-cmd --list-all   # RHEL/CentOS
   sudo ufw status               # Ubuntu/Debian
   ```

3. **Permission problems**:
   ```bash
   # Check ownership of data directory
   ls -la /var/lib/ldap/
   
   # Fix permissions if needed
   sudo chown -R ldap:ldap /var/lib/ldap/
   ```

## Integration with Active Directory

### Configuring OpenLDAP as a Proxy to Active Directory

1. **Install necessary schema**:
   ```bash
   sudo apt install schema2ldif
   ```

2. **Create the proxy configuration**:
   ```bash
   cat > ad_proxy.ldif << EOF
   dn: cn=module,cn=config
   objectClass: olcModuleList
   cn: module
   olcModulePath: /usr/lib/ldap
   olcModuleLoad: rwm

   dn: olcDatabase=ldap,cn=config
   objectClass: olcDatabaseConfig
   objectClass: olcLDAPConfig
   olcDatabase: ldap
   olcDbURI: "ldap://ad.example.com"
   olcSuffix: "dc=example,dc=org"
   olcRootDN: "cn=admin,dc=example,dc=org"
   olcRootPW: secret
   olcAccess: to * by * read
   EOF
   ```

3. **Apply the configuration**:
   ```bash
   sudo ldapadd -Y EXTERNAL -H ldapi:/// -f ad_proxy.ldif
   ```

## Best Practices

1. **Regular backups**:
   ```bash
   # Create a backup script
   cat > backup_ldap.sh << EOF
   #!/bin/bash
   BACKUP_DIR="/backup/ldap"
   TIMESTAMP=\$(date +%Y%m%d%H%M%S)
   mkdir -p \$BACKUP_DIR
   slapcat -n 0 -l \$BACKUP_DIR/config_\$TIMESTAMP.ldif
   slapcat -n 1 -l \$BACKUP_DIR/data_\$TIMESTAMP.ldif
   tar -czf \$BACKUP_DIR/ldap_backup_\$TIMESTAMP.tar.gz \$BACKUP_DIR/*.ldif
   find \$BACKUP_DIR -name "*.ldif" -type f -mtime +7 -delete
   EOF
   
   chmod +x backup_ldap.sh
   ```

2. **Implement access controls**:
   ```
   dn: olcDatabase={1}mdb,cn=config
   changetype: modify
   add: olcAccess
   olcAccess: {0}to attrs=userPassword by self write by anonymous auth by * none
   olcAccess: {1}to * by self write by users read
   ```

3. **Monitoring**:
   ```bash
   # Install monitoring tools
   sudo apt install nagios-plugins
   
   # Check LDAP status
   /usr/lib/nagios/plugins/check_ldap -H localhost -b "dc=example,dc=org"
   ```

## Conclusion

This guide covers the basic setup and configuration of OpenLDAP on Linux systems. For production environments, consider implementing additional security measures, high availability configurations, and regular maintenance procedures.

Remember to replace example domains, usernames, and passwords with your actual information when implementing this guide.