provider "azurerm" {
  subscription_id = "f49b1c11-f5fb-42ca-97b4-44e570b9c0e9"
  features {}
}

resource "azurerm_resource_group" "EHH-01" {
  name     = "${var.prefix}-resources"
  location = "${var.location}"
}

resource "azurerm_virtual_network" "EHH-01" {
  name                = "${var.prefix}-network"
  address_space       = ["192.168.0.0/16"]
  location            = azurerm_resource_group.EHH-01.location
  resource_group_name = azurerm_resource_group.EHH-01.name
  dns_servers         = ["192.168.1.10"]
}

resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.EHH-01.name
  virtual_network_name = azurerm_virtual_network.EHH-01.name
  address_prefixes     = ["192.168.1.0/24"]
}

resource "azurerm_public_ip" "EHH-01_public_ip" {
  name                = "${var.prefix}-public-ip"
  location            = azurerm_resource_group.EHH-01.location
  resource_group_name = azurerm_resource_group.EHH-01.name
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "EHH-01" {
  name                = "${var.prefix}-nic"
  resource_group_name = azurerm_resource_group.EHH-01.name
  location            = azurerm_resource_group.EHH-01.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.EHH-01_public_ip.id
  }
}

resource "azurerm_network_security_group" "EHH-01_nsg" {
  name                = "${var.prefix}-nsg"
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

# Verknüpfe die Netzwerkschnittstelle mit der NSG
resource "azurerm_network_interface_security_group_association" "EHH-01_nsg_association" {
  network_interface_id      = azurerm_network_interface.EHH-01.id
  network_security_group_id = azurerm_network_security_group.EHH-01_nsg.id
}

resource "azurerm_windows_virtual_machine" "EHH-01" {
  name                = "${var.prefix}-vm"
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

resource "azurerm_virtual_machine_extension" "web_server_install" {
  name                       = "${var.prefix}-wsi"
  virtual_machine_id         = azurerm_windows_virtual_machine.EHH-01.id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"  # Stelle sicher, dass die neueste Version verwendet wird
  auto_upgrade_minor_version = true

  settings = <<SETTINGS
    {
      "commandToExecute": "powershell -ExecutionPolicy Unrestricted -Command \"Install-WindowsFeature -Name Web-Server -IncludeAllSubFeature -IncludeManagementTools\""
    }
  SETTINGS
}
