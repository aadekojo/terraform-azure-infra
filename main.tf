# Configure the Azure provider
provider "azurerm" {
	features{}

    subscription_id = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxx" #input youurs here
}

# Resource Group
resource "azurerm_resource_group" "rg" {
	name = "Terraform-RG"
	location = "East US"
}

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "azureproject_vnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

# Subnet
resource "azurerm_subnet" "subnet" {
  name                 = "azureproject_subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Storage Account
resource "azurerm_storage_account" "storage" {
  name                     = "azureprojectstgacct"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Virtual Machine
resource "azurerm_public_ip" "vm_ip" {
  name                = "azureproject-vm-ip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "nic" {
  name                = "azureproject-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm_ip.id
  }
}
resource "azurerm_virtual_machine" "vm" {
  name                  = "azureproject-vm"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.nic.id]
  vm_size               = "Standard_B1s"

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "myosdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
  }

  os_profile {
    computer_name  = "azureproject-vm"
    admin_username = "azureuser"
    admin_password = "AzurePassword!"
  }

   os_profile_linux_config {
    disable_password_authentication = false
  }
}

# Create a Network Security Group
resource "azurerm_network_security_group" "nsg" {
  name                = "azureproject-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create a Security Rule to Allow SSH
resource "azurerm_network_security_rule" "allow_ssh" {
  name                        = "allow-ssh"
  priority                    = 1001
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "0.0.0.0/0" # (Limit this to your IP for better security)
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

# Associate NSG with the Subnet
resource "azurerm_subnet_network_security_group_association" "nsg_association" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}



terraform{
    backend "azurerm" {
        resource_group_name  = "Terraform-Backend-RG"
        storage_account_name = "terraformprojectacct"
        container_name       = "tfstate"
        key                  = "terraform.tfstate"
    }
}
