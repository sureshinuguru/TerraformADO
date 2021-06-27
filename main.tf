terraform {
  backend "azurerm" {
    resource_group_name   = "sinuguru-infra"
    storage_account_name  = "sinugurutstate"
    container_name        = "tstate"
    key                   = "77Q4LUB5o9wRdbPYDt+0kGZP+L8Sj9E/FNXg7lZBQS5z3mLod5cyan4wA19CR1SmlqIRUFQfhuQrPVaGzNhjGw=="
}

  required_providers {
    azurerm = {
      # Specify what version of the provider we are going to utilise
      source = "hashicorp/azurerm"
      version = ">= 2.4.1"
    }
  }
}
provider "azurerm" {
  features {
      key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
}
data "azurerm_client_config" "current" {}
# Create our Resource Group - sinuguru-RG
resource "azurerm_resource_group" "rg" {
  name     = "sinuguru-app01"
  location = "UK South"
}
# Create our Virtual Network - sinuguru-VNET
resource "azurerm_virtual_network" "vnet" {
  name                = "sinuguruvnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}
# Create our Subnet to hold our VM - Virtual Machines
resource "azurerm_subnet" "sn" {
  name                 = "VM"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes       = ["10.0.1.0/24"]
}
variable "count" {default = 2} 
# Create our Azure Storage Account - sinugurusa
resource "azurerm_storage_account" "sinugurusa" {
  name                     = "sinugurusa"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags = {
    environment = "sinuguruenv1"
  }
}
# Create our Azure Network Security Group - sinugurunsg
resource "azurerm_network_security_group" "sinugurunsg" {
  name                = "${var.application_nsg}"
  location            = "${azurerm_resource_group.sinugururg.location}"
  resource_group_name = azurerm_resource_group.sinugururg.name
}

resource "azurerm_network_security_rule" "sinuguru-nsg-80" {
  name                        = "Open Port 80"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "HTTP"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name = azurerm_resource_group.sinugururg.name
  network_security_group_name = azurerm_network_security_group.sinugurunsg,name
}

resource "azurerm_network_security_rule" "sinuguru-nsg-443" {
  name                        = "Open Port 443"
  priority                    = 101
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "HTTPS"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name = azurerm_resource_group.sinugururg.name
  network_security_group_name = azurerm_network_security_group.sinugurunsg,name
}
# Create our vNIC for our VM and assign it to our Virtual Machines Subnet
resource "azurerm_network_interface" "vmnic" {
  name                = "sinuguruvm01nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  network_security_group_id = azurerm_network_security_group.nsg.id
 
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.sn.id
    private_ip_address_allocation = "Dynamic"
  }
}
# Create our Virtual Machine - sinuguru-VM01
resource "azurerm_virtual_machine" "sinuguruvm01" {
depends_on = [ azurerm_key_vault.kv1 ]
  name                  = "sinuguru01"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.vmnic.id]
  vm_size               = "Standard_B2s"
  admin_username      = "admin"
  admin_password      = azurerm_key_vault_secret.vmpassword.value
  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter-Server-Core-smalldisk"
    version   = "latest"
  }
  storage_os_disk {
    name              = "sinuguruvm01os"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name      = "sinuguruvm01"
    admin_username     = "sinuguru"
    admin_password     = "Password123$"
  }
  os_profile_windows_config {
  }
}

#Create KeyVault ID
resource "random_id" "kvname" {
  byte_length = 5
  prefix = "keyvault"
}
#Keyvault Creation
data "azurerm_client_config" "current" {}
resource "azurerm_key_vault" "kv1" {
  depends_on = [ azurerm_resource_group.sinugururg ]
  name                        = random_id.kvname.hex
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  sku_name = "standard"
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id
    key_permissions = [
      "get",
    ]
    secret_permissions = [
      "get", "backup", "delete", "list", "purge", "recover", "restore", "set",
    ]
    storage_permissions = [
      "get",
    ]
  }
}
#Create KeyVault VM password
resource "random_password" "vmpassword" {
  length = 20
  special = true
}
#Create Key Vault Secret
resource "azurerm_key_vault_secret" "vmpassword" {
  name         = "vmpassword"
  value        = random_password.vmpassword.result
  key_vault_id = azurerm_key_vault.kv1.id
  depends_on = [ azurerm_key_vault.kv1 ]
}
