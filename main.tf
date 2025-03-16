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
