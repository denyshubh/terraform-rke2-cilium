resource "azurerm_virtual_network" "rke2_vnet" {
  name                = "rke2-vnet"
  address_space       = ["10.7.0.0/16"]
  location            = "East US"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_subnet" "rke2_subnet" {
  name                 = "rke2-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.rke2_vnet.name
  address_prefixes     = ["10.7.1.0/24"]
}

output "subnet_id" {
  value = azurerm_subnet.rke2_subnet.id
}
