variable VMName {
    type = string
    description = "Name of the virtual machine we will create"
}

variable ResourceGroupName {
    type = string
    default = "app-jlindsey2"
}

variable VMSize {
    type = string
    description = "Size of the created virtual machine"
    default = "Standard_B2s"
}

variable Location {
  type = string
  default = "Central US"
}

variable VNetName {
    type = string
    description = "Name of the VNet that we will attach our VM to"
}

variable SubnetName {
    type = string
    description = "Subnet we will attach our VM to"
    default = "default"
}

variable AdminUsername {
    type = string
    description = "Username for the virtual machine"
}


variable AdminSSHKey {
    type = string
    description = "SSH public key for the VM"
}

terraform {
    required_providers {
        azure = {
            source = "opentofu/azurerm"
            version = "3.84.0"
        }
    }
}

import {
  to = azurerm_virtual_network.vNet
  id = "/subscriptions/ff95cccd-cbb7-41a2-b4ba-41917218c03c/resourceGroups/app-jlindsey2/providers/Microsoft.Network/virtualNetworks/ansible-test-vnet"
}

resource "azurerm_virtual_network" "vNet" {
  name = var.VNetName
  location = var.Location
  resource_group_name = var.ResourceGroupName
  address_space = [ "10.0.0.0/16" ]
}

resource "azurerm_network_security_group" "nsg" {
    name = "${var.VMName}-nsg"
    location = var.Location
    resource_group_name = var.ResourceGroupName
    security_rule = [{
        name = "SSH"
        priority = 1000
        protocol = "Tcp"
        access = "Allow"
        direction = "Inbound"
        source_address_prefix = "*"
        source_port_range = "*"
        destination_address_prefix = "*"
        desintation_port_range = "22"
    },
    {
        name = "HTTP"
        priority = 1001
        protcol = "Tcp"
        access = "Allow"
        direction = "Inbound"
        source_address_prefix = "*"
        source_port_range = "*"
        destination_address_prefix = "*"
        desintation_port_range = "80"
    },
    {
        name = "HTTPS"
        priority = 1002
        protcol = "Tcp"
        access = "Allow"
        direction = "Inbound"
        source_address_prefix = "*"
        source_port_range = "*"
        destination_address_prefix = "*"
        desintation_port_range = "443"
    }]
}

resource "azurerm_public_ip" "publicIP" {
    name = "${var.VMName}-PublicIP"
    location = var.Location
    resource_group_name = var.ResourceGroupName
    sku = "Basic"
    allocation_method = "Dynamic"
    idle_timeout_in_minutes = 4
    ip_version = "IPv4"
}

resource "azurerm_network_interface" "nic" {
  name = "${var.VMName}-NIC"
  location = var.Location
  resource_group_name = var.ResourceGroupName
  ip_configuration {
    name = "ipconfig1"
    private_ip_address_allocation = "Dynamic"
    subnet_id = azurerm_virtual_network.vNet.subnet.id
    public_ip_address_id = azurerm_public_ip.publicIP.id
  }
}

resource "azurerm_virtual_machine" "vm" {
    name = var.VMName
    location = var.Location
    resource_group_name = var.ResourceGroupName
    vm_size = var.VMSize
    delete_data_disks_on_termination = true
    delete_os_disk_on_termination = true
    network_interface_ids = [
        azurerm_network_interface.nic.id
    ]
    storage_os_disk {
        name = "${var.VMName}-OSDisk"
        caching = "ReadWrite"
        managed_disk_type = "StandardSSD_LRS"
        disk_size_gb = 128
        create_option = "FromImage"
    }
    storage_image_reference {
      publisher = "canonical"
      offer = "0001-com-ubuntu-server-jammy"
      version = "latest"
      sku = "22_04-lts-gen2"
    }
    os_profile {
      computer_name = var.VMName
      admin_username = var.AdminUsername
    }
    os_profile_linux_config {
      disable_password_authentication = true
      ssh_keys {
        path = "/home/${var.AdminUsername}/.ssh/authorized_keys"
        key_data = file("~/.ssh/${var.AdminSSHKey}")
      }
    }
    storage_data_disk {
      name = "${var.VMName}-DataDisk"
      caching = "ReadWrite"
      create_option = "Empty"
      disk_size_gb = 1023
      lun = 0
    }
}