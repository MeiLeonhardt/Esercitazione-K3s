provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

resource "azurerm_resource_group" "K3s_Lab" {
  name     = "K3s-Lab"
  location = "West Europe"

}

#1. creo la Virtual Network e Subnet utilizzando le variabili
resource "azurerm_virtual_network" "vnet_master" {
  name                = "${var.prefix}-vnet-master"
  location            = azurerm_resource_group.K3s_Lab.location
  resource_group_name = azurerm_resource_group.K3s_Lab.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "subnet_master" {
  name                 = "${var.prefix}-subnet-master"
  resource_group_name  = azurerm_resource_group.K3s_Lab.name
  virtual_network_name = azurerm_virtual_network.vnet_master.name
  address_prefixes     = ["10.0.1.0/24"]
}

#2. Creo l'interfaccia di rete
resource "azurerm_network_interface" "network_interface_K3s" {
  for_each            = var.vm_master
  name                = "net-int-${var.prefix}-${each.key}" #Nella risorsa azurerm_network_interface, il nome dell'interfaccia era definito come "net-int-${var.prefix}" che sarebbe stato identico per tutte le VM nel ciclo for_each.
  location            = azurerm_resource_group.K3s_Lab.location
  resource_group_name = azurerm_resource_group.K3s_Lab.name

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = azurerm_subnet.subnet_master.id
    private_ip_address_allocation = "Dynamic"
  }
}

#3. creo la VM
resource "azurerm_linux_virtual_machine" "vm_master" {
  for_each = var.vm_master

  name                            = each.key
  resource_group_name             = azurerm_resource_group.K3s_Lab.name
  location                        = azurerm_resource_group.K3s_Lab.location
  size                            = each.value.vm_size
  admin_username                  = "azureuser"
  admin_password                  = "Password!£!?"
  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.network_interface_K3s[each.key].id
  ]

  source_image_reference {
    publisher = each.value.image.publisher
    offer     = each.value.image.offer
    sku       = each.value.image.sku
    version   = each.value.image.version
  }

  os_disk {
    name                 = "${each.key}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  tags = each.value.tags
}

resource "azurerm_network_security_group" "K3s_nsg" {
  name                = "${var.prefix}-nsg"
  location            = azurerm_resource_group.K3s_Lab.location
  resource_group_name = azurerm_resource_group.K3s_Lab.name

  security_rule {
    name                       = "Allow_SSH_TCP_22"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Associazione del gruppo di sicurezza alla subnet
resource "azurerm_subnet_network_security_group_association" "nsg_association" {
  subnet_id                 = azurerm_subnet.subnet_master.id
  network_security_group_id = azurerm_network_security_group.K3s_nsg.id
}