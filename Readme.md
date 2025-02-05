## Table of Contents

- [🚀 Project Overview]
- [🔧 Prerequisites]
- [🛠 Step-by-Step Implementation]
    [1. Azure Setup](#1-azure-setup)
    [2. Initialize Terraform](#2-initialize-terraform)
    [3. Define Resources & Apply the Plan](#3-define-resources)
    [4. Access the VM](#4-access-the-vm)
-  [⚠️ Pitfalls and Troubleshooting](#Pitfalls)
- [🧹 Cleanup](#Cleanup)
## Project Overview

This project demonstrates the automation of **Azure infrastructure** using **Terraform** and **Azure DevOps**. We created a virtual network, subnet, storage account, and a virtual machine (VM) while ensuring the environment is secure and properly configured.
# 🔧 Prerequisites

Required Tools
- **Azure Account**: Make sure you have an Azure account and a **default directory** set up.
- **Terraform**: Install Terraform on your local machine.
- **Azure CLI**: Install Azure CLI to interact with your Azure account.
- **GitHub Account:** store repo and version control
- **Your preferred IDE** 
Use the following Code to verify installation
```bash
az --version  # Check Azure CLI version
terraform -version  # Check Terraform version
git --version  # Check Git version
```

# 🛠 Step-by-Step Implementation

### 1-azure-setup
##### Auth to Azure via CLI (other means are fine e.g. vscode extensions)
[ ] - log in to azure on terminal ``` az login ``` 
[ ] - Verify your default subscription ```az account show --output table ```
----  you could also create a repo on GitHub and clone it locally ***Requires git config setup***

### 2-initialize-terraform
##### Terraform Code for Infrastructure
Create directory ***terraform*** and create a file named ***main.tf***

main.tf
```
# Configure the Azure provider
provider "azurerm" {
    features{}
}

# Resource Group
resource "azurerm_resource_group" "rg" {
    name = "Terraform-RG"
    location = "East US"
}
```
##### Store Terraform State in Azure Storage
Create an azure storage account to store the files; ideally this should be automated but for this project I'll be doing it manually.

I used the GUI to do this but I'll include a CLI version for those interested { tweak as needed}
```
az group create --name Terraform-Backend-RG --location "East US"

az storage account create \
    --name terraformprojectacct \
    --resource-group Terraform-Backend-RG \
    --location "East US" \
    --sku Standard_LRS

az storage container create \
    --name tfstate \
    --account-name terraformprojectacct

```

Modify *main.tf* to use remote backend

terraform initialization commands
```bash
teraform init
terraform plan
terraform apply -auto-approve
```
 X - you might run into an error when you hit terraform plan, you need to add your subscription id as a parameter in *main.tf*

### 3-define-resources 

We will be adding:
- Virtual Network - networking
- Subnet - For organizing resources
- Storage account - you guessed it storing data
- Virtual Machine(VM) - compute resources
##### Update *main.tf* to Add Resources

```
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
resource "azurerm_network_interface" "nic" {
  name                = "azureproject-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
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
    admin_password = "YourSecurePassword!"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
}

```

Apply the and approve the changes
```
terraform plan
terraform apply -auto-approve
```

##### Verify Deployment
Check resources:
```bash
az resource list --resource-group Terraform-RG --output table
```
Or if you're like me you have the Azure Portal open -> Resource Groups -> Terraform-RG

### 4-access-the-VM

In this part I'm going to:
- connect to the VM vis SSH
- set up a Network Security Group (NSG) to allow SSH access

#### Create a NSG for SSH access
modify main.tf and add the following 
```
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

```
After saving, run:
```bash
terraform plan
terraform apply -auto-approve
```
Now, get the public IP of the VMs:
```bash
az vm list-ip-addresses --name azureproject-vm --output table
```

#### Connect to your VM via SSH
once you get the public IP
```bash
ssh azureuser@<public IP>
```

Note: you should use SSH Authentication instead of passwords but for the purpose of this project I will not be doing that.

Errors you might run into:
- SSH connection timeout -> if you followed my setup it's probably caused by not creating a public ip you can add that in the *main.tf* , save and apply with terraform.

# Pitfalls

- **Subscription ID is required"**: Make sure your Terraform configuration includes the **subscription ID** in the provider block.
```
provider "azurerm" {   
    subscription_id = "<your_subscription_id>" }
```
- **SSH Timeout**: If SSH access times out, ensure:
    - Your **VM has a public IP**.
    - The **Network Security Group (NSG)** allows SSH (Port 22).
    - The **VM is running** (not stopped).
- **Static IP Requirement**: Azure requires **static public IP** for VMs. Ensure you set the **allocation method** to `"Static"` for your **public IP resource**.
    Example:
    
```
resource "azurerm_public_ip" "vm_ip" {
  allocation_method = "Static"
}
```

- **No Ping Response**: Ensure your **NSG** allows ICMP or use the **static IP** for the VM.
# Cleanup

After completing the project, remember to clean up the resources to avoid additional costs.
### 1. Remove Resources via Terraform
Run the following command to destroy all resources created by Terraform:
```
terraform destroy -auto-approve
```
This will clean up all the resources defined in the *main.tf* file.

### 2. Verify Resource Deletion
You can confirm the resources are deleted by running 
```
az resource list --resource-group azureproject_resource_group --output table
```
If some resources still exist, delete them manually via the **Azure Portal** or use the Azure CLI to remove them.
```
az group delete --name azureproject_resource_group --yes --no-wait
```

### 3. Remove Terraform State
Finally, delete the Terraform state files (`terraform.tfstate` and `terraform.tfstate.backup`) from your local environment:
```
rm terraform.tfstate terraform.tfstate.backup
```

I prefer doing it through Azure Portal

### Conclusions and Notes
##### Cost Analysis (I assume you don't want to splurge)

| Resource             | Cost Per Month (USD) |
| -------------------- | -------------------- |
| Resource Group       | free                 |
| Virtual Network      | free                 |
| Storage Account      | ~$5 (LRS, 100GB)     |
| Virtual Machine(B1s) | ~$7 (Pay-as-you-go)  |
| Total(Approx.)       | $12 -$15             |
Hint - Make sure to use auto-shutdown for VMs and delete unused resources to cut cost
#### Time Analysis

| Task                            | Time Required |
| ------------------------------- | ------------- |
| Set up Azure DevOps & Terraform | 1 - 2 hours   |
| Write Terraform Code            | 1 - 2hours    |
| Test Deployment Locally         | 1 hour        |
| End - End Testing & Debugging   | 2 - 4 hours   |
| Total(Approx.)                  | 4 - 9 hours   |
Note - these are very conservative timeframes and depend on skill level, this timeframe is specific to me, most of my time actually went into testing and debugging 
