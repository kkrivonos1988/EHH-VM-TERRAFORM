provider "azurerm" {
  subscription_id = "f4271ee4-c913-4d2e-b833-7c509d41a2e4"
  features {}
}

resource "azurerm_resource_group" "EHH-01" {
  name     = "EHH-01-resources"
  location = "germanywestcentral"
}

resource "azurerm_virtual_network" "EHH-01" {
  name                = "EHH-01-network"
  address_space       = ["192.168.0.0/16"]
  location            = azurerm_resource_group.EHH-01.location
  resource_group_name = azurerm_resource_group.EHH-01.name
}

resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.EHH-01.name
  virtual_network_name = azurerm_virtual_network.EHH-01.name
  address_prefixes     = ["192.168.1.0/24"]
}

resource "azurerm_public_ip" "EHH01_public_ip" {
  name                = "EHH-01-public-ip"
  location            = azurerm_resource_group.EHH-01.location
  resource_group_name = azurerm_resource_group.EHH-01.name
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "EHH-01" {
  name                = "EHH-01-nic"
  resource_group_name = azurerm_resource_group.EHH-01.name
  location            = azurerm_resource_group.EHH-01.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.EHH01_public_ip.id
  }
}

resource "azurerm_virtual_network_dns_servers" "EHH-01-DNS" {
  
  virtual_network_id = azurerm_virtual_network.EHH-01.id
  dns_servers = ["192.168.1.10"]
}

resource "azurerm_network_security_group" "EHH01_nsg" {
  name                = "EHH-01-nsg"
  location            = azurerm_resource_group.EHH-01.location
  resource_group_name = azurerm_resource_group.EHH-01.name

  security_rule {
    name                       = "RDP"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "web"
    priority                   = 310
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}


resource "azurerm_windows_virtual_machine" "EHH-01" {
  name                = "EHH-01-vm"
  resource_group_name = azurerm_resource_group.EHH-01.name
  location            = azurerm_resource_group.EHH-01.location
  size                = "Standard_B2s"
  admin_username      = "adminuser"
  admin_password      = "Start123$*"
  network_interface_ids = [
    azurerm_network_interface.EHH-01.id,
  ]

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }

  os_disk {
    name                 = "System"
    disk_size_gb         = 127
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }
   
}