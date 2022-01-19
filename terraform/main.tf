# Configure the Microsoft Azure Provider
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "~>2.0"
    }
  }
}
provider "azurerm" {
  subscription_id = "__subid__"
  client_id = "__clientid__"
  client_secret = "__clientsecret__"
  tenant_id = "__tenantid__"
  environment = "china"
  features {}
}

# Create a resource group if it doesn't exist
resource "azurerm_resource_group" "myterraformgroup" {
    name     = "myResourceGroup"
    location = "china north 2"

    tags = {
        environment = "Terraform Demo"
    }
}

data "azurerm_shared_image" "example" {
  name                = "prjvmdf"
  gallery_name        = "prjga"
  resource_group_name = "templaterg"
}

# Create virtual network
resource "azurerm_virtual_network" "myterraformnetwork" {
    name                = "myVnet"
    address_space       = ["10.0.0.0/16"]
    location            = "china north 2"
    resource_group_name = azurerm_resource_group.myterraformgroup.name

    tags = {
        environment = "Terraform Demo"
    }
}

# Create subnet
resource "azurerm_subnet" "myterraformsubnet" {
    name                 = "mySubnet"
    resource_group_name  = azurerm_resource_group.myterraformgroup.name
    virtual_network_name = azurerm_virtual_network.myterraformnetwork.name
    address_prefixes       = ["10.0.1.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "myterraformpublicip" {
    name                         = "myPublicIP"
    location                     = "china north 2"
    resource_group_name          = azurerm_resource_group.myterraformgroup.name
    allocation_method            = "Dynamic"

    tags = {
        environment = "Terraform Demo"
    }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "myterraformnsg" {
    name                = "myNetworkSecurityGroup"
    location            = "china north 2"
    resource_group_name = azurerm_resource_group.myterraformgroup.name

    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22,8080"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags = {
        environment = "Terraform Demo"
    }
}

# Create network interface
resource "azurerm_network_interface" "myterraformnic" {
    name                      = "myNIC"
    location                  = "china north 2"
    resource_group_name       = azurerm_resource_group.myterraformgroup.name

    ip_configuration {
        name                          = "myNicConfiguration"
        subnet_id                     = azurerm_subnet.myterraformsubnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.myterraformpublicip.id
    }

    tags = {
        environment = "Terraform Demo"
    }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "example" {
    network_interface_id      = azurerm_network_interface.myterraformnic.id
    network_security_group_id = azurerm_network_security_group.myterraformnsg.id
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = azurerm_resource_group.myterraformgroup.name
    }

    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "mystorageaccount" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = azurerm_resource_group.myterraformgroup.name
    location                    = "china north 2"
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags = {
        environment = "Terraform Demo"
    }
}


# Create virtual machine
resource "azurerm_linux_virtual_machine" "myterraformvm" {
    name                  = "myVM"
    location              = "china north 2"
    resource_group_name   = azurerm_resource_group.myterraformgroup.name
    network_interface_ids = [azurerm_network_interface.myterraformnic.id]
    size                  = "Standard_DS1_v2"

    os_disk {
        name              = "myOsDisk"
        caching           = "ReadWrite"
        storage_account_type = "Premium_LRS"
    }

admin_ssh_key {
    username   = "hadoop"
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAstWy9ALdE6cTH7t4h871XGmSEtEXLOemQ8o091QMAWnrszkMtTa2rPhRjD2Z4FmF3Ih0vs0F2dRRbCTyvKVgY6q9kJBdCaDctR4pQxOHIxcHZTOb/+HdcLEGngTeFZk1HKqNWJPgRHQXUl5bVysAxsbRTsJHT4ZVH3BATBO9UqtdTA52ODYLU10mRNAjz9tOZGnYvQjAANjbli6peW1jToR1t5GMxUV/0MVI+hvXACMNRlfC74JCBu/LmBUT8f1h8Qjrab2qdBM0wNCncm2/QoGelE6dBZ6bsX3HhiTjxgrhWwFBuWgbHuha6guBaEJ2idA8Mp3hviDteWr2B+o1fw=="
  }

#    source_image_reference {
#        publisher = "prjpub"
#        offer     = "prjoffer"
#        sku       = "prjsku"
#        version   = "1.0.0"
#    }
    source_image_id = data.azurerm_shared_image.example.id

    computer_name  = "myvm"
    admin_username = "hadoop"


    boot_diagnostics {
        storage_account_uri = azurerm_storage_account.mystorageaccount.primary_blob_endpoint
    }

    tags = {
        environment = "Terraform Demo"
    }
}

resource "azurerm_virtual_machine_extension" "example" {
  name                 = "hostname"
  virtual_machine_id   = azurerm_linux_virtual_machine.myterraformvm.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  settings = <<SETTINGS
    {
        "commandToExecute": "wget -P /usr/local/tomcat/webapps/ https://bochendiag.blob.core.chinacloudapi.cn/files/myshuttledev.war"
    }
SETTINGS


  tags = {
    environment = "Terraform Demo"
  }
}
