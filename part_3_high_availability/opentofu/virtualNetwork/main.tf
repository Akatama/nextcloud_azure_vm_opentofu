variable "Location" {
  type = string
  default = "Central US"
}

variable "VNetName" {
    type = string
    default = "nextcloud-tofu-vnet"
}

variable "ResourceGroupName" {
    type = string
    description = "The resource group where the virtual network will be placed"
    default = "nextcloud-tofu-network"
}

variable "ServerSubnetName" {
    type = string
    default = "server"
    description = "The name of the Subnet where we will attach our servers"
}

variable "ServerSubnetPrefix" {
    type = string
    default = "10.2.0.0/24"
    description = "The Address Prefix for the Server subnet"
}

variable "DBSubnetName" {
  type = string
  default = "database"
  description = "The name of the Subnet where we will attach our database"
}

variable "DBSubnetPrefix" {
    type = string
    default = "10.2.1.0/24"
    description = "The Address Prefix for the DB subneet"
}

resource "azurerm_resource_group" "resource_group" {
    name = var.ResourceGroupName
    location = var.Location
}

resource "azurerm_virtual_network" "vnet" {
    name = var.VNetName
    location = var.Location
    resource_group_name = azurerm_resource_group.resource_group.name
    address_space = ["10.2.0.0/16"]
}

resource "azurerm_subnet" "db_subnet" {
    name = var.DBSubnetName
    resource_group_name = azurerm_resource_group.resource_group.name
    virtual_network_name = azurerm_virtual_network.vnet.name
    address_prefixes = [var.DBSubnetPrefix]
    delegation {
        name = "MySQLFlexibleServers"
        service_delegation {
          name = "Microsoft.DBforMySQL/flexibleServers"
        }
    }  
}

resource "azurerm_subnet" "server_subnet" {
    name = var.ServerSubnetName
    resource_group_name = azurerm_resource_group.resource_group.name
    virtual_network_name = azurerm_virtual_network.vnet.name
    address_prefixes = [var.ServerSubnetPrefix]
    service_endpoints = ["Microsoft.Storage"]
}