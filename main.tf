###############################################################################
# Configure the Azure Provider
###############################################################################
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.2"
    }
  }

  required_version = ">= 1.1.0"
}
provider "azurerm" {
  features {}
}

###############################################################################
# 1. Resource Group
###############################################################################
resource "azurerm_resource_group" "rg" {
  name     = "rg-3tier-terraform"
  location = "eastus"
}

###############################################################################
# 2. Virtual Network and Subnets
###############################################################################
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-3tier"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "subnet_appgw" {
  name                 = "subnet-appgw"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.0.0/24"]
}

resource "azurerm_subnet" "subnet_app" {
  name                 = "subnet-app"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

###############################################################################
# 3. Public IP for Application Gateway
###############################################################################
resource "azurerm_public_ip" "appgw_public_ip" {
  name                = "pip-appgw"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"
  allocation_method   = "Static"
}



###############################################################################
# 4. Application VM
###############################################################################
resource "azurerm_network_interface" "app_nic" {
  name                = "nic-app-vm"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.subnet_app.id
    private_ip_address_allocation = "Dynamic"
    #public_ip_address_id          = azurerm_public_ip.vm_public_ip.id
  }
}

resource "azurerm_linux_virtual_machine" "app_vm" {
  name                = "vm-app-tier"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B1s"
  admin_username      = "azureuser"
  network_interface_ids = [
    azurerm_network_interface.app_nic.id
  ]

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }

  # Specify the OS disk settings
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = "osdisk-app-vm"
    disk_size_gb         = 30
  }

    admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/authorized_keys.pub")
  }

  custom_data = base64encode(
    <<-EOT
      #!/bin/bash
      sudo apt-get update -y
      sudo apt-get install apache2 -y
      echo "<h1>Welcome to the 3-tier Demo!</h1>" | sudo tee /var/www/html/index.html
      sudo systemctl enable apache2
      sudo systemctl start apache2
    EOT
  )
}

locals {
  backend_address_pool_name      = "${azurerm_network_interface.app_nic.private_ip_address}-beap"

}

###############################################################################
# 5. Application Gateway
###############################################################################
resource "azurerm_application_gateway" "app_gw" {
  name                = "agw-3tier"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "gwipconfig"
    subnet_id = azurerm_subnet.subnet_appgw.id
  }

  frontend_port {
    name = "port80"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "frontendip"
    public_ip_address_id = azurerm_public_ip.appgw_public_ip.id
  }

  # OLD-STYLE backend_addresses (list) vs. nested block
  backend_address_pool {
    name = local.backend_address_pool_name 
    ip_addresses = azurerm_network_interface.app_nic.private_ip_addresses

    # Instead of "backend_addresses { ip_address = ... }"
    # we use a list of address objects
  }

  backend_http_settings {
    name                  = "backendhttp"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 30
  }

  http_listener {
    name                           = "httplistener"
    frontend_ip_configuration_name = "frontendip"
    frontend_port_name             = "port80"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "routingrule"
    rule_type                  = "Basic"
    http_listener_name         = "httplistener"
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = "backendhttp"
  }

  # For WAF_v2, you must define waf_configuration
  # If you want it disabled:
  waf_configuration {
    enabled       = false
    firewall_mode = "Prevention"
    rule_set_type    = "OWASP"
    rule_set_version = "3.2"
  }
}

###############################################################################
# 6. Outputs
###############################################################################
output "app_gateway_public_ip" {
  description = "Public IP of the Application Gateway"
  value       = azurerm_public_ip.appgw_public_ip.ip_address
}
