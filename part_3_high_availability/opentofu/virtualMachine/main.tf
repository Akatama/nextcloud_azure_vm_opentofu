variable VMName {
    type = string
    description = "Name of the virtual machine we will create"
}

variable ResourceGroupName {
    type = string
    default = "nextcloud-tofu-server"
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
    default = "server"
}

variable "VNetResourceGroupName" {
  type = string
  description = "Resource group that the VNet belongs to"
  default = "nextcloud-tofu-network"
}

variable AdminUsername {
    type = string
    description = "Username for the virtual machine"
}


variable AdminSSHKey {
    type = string
    description = "SSH public key for the VM"
    sensitive = true
}

variable ItemCount {
  type = number
  description = "Number of VMs to create"
}

terraform {
    required_providers {
        azurerm = {
            source = "opentofu/azurerm"
            version = "3.84.0"
        }
    }
}

provider "azurerm" {
  features{}
  
}

data "azurerm_subnet" "subnet" {
  name = var.SubnetName
  virtual_network_name = var.VNetName
  resource_group_name = var.VNetResourceGroupName
}

resource "azurerm_resource_group" "resource_group" {
    name = var.ResourceGroupName
    location = var.Location
}

resource "azurerm_network_security_group" "nsg" {
    name = "${var.VMName}-nsg"
    location = var.Location
    resource_group_name = azurerm_resource_group.resource_group.name
    security_rule {
        name = "SSH"
        description = "SSH connection"
        priority = 1000
        protocol = "Tcp"
        access = "Allow"
        direction = "Inbound"
        source_address_prefix = "*"
        source_port_range = "*"
        destination_address_prefix = "*"
        destination_port_range= "22"
      }
    security_rule {
        name = "HTTP"
        description = "HTTP connection"
        priority = 1001
        protocol = "Tcp"
        access = "Allow"
        direction = "Inbound"
        source_address_prefix = "*"
        source_port_range = "*"
        destination_address_prefix = "*"
        destination_port_range = "80"
      }
      security_rule {
        name = "HTTPS"
        description = "HTTPS connection"
        priority = 1002
        protocol = "Tcp"
        access = "Allow"
        direction = "Inbound"
        source_address_prefix = "*"
        source_port_range = "*"
        destination_address_prefix = "*"
        destination_port_range = "443"
      }
}

resource "azurerm_public_ip" "publicIP" {
    name = "${var.VMName}-PublicIP"
    location = var.Location
    resource_group_name = azurerm_resource_group.resource_group.name
    sku = "Basic"
    allocation_method = "Dynamic"
    idle_timeout_in_minutes = 4
    ip_version = "IPv4"
}

resource "azurerm_network_interface" "nic" {
  name = "${var.VMName}-NIC"
  location = var.Location
  resource_group_name = azurerm_resource_group.resource_group.name
  ip_configuration {
    name = "ipconfig1"
    private_ip_address_allocation = "Dynamic"
    subnet_id = data.azurerm_subnet.subnet.id
    public_ip_address_id = azurerm_public_ip.publicIP.id
  }
}

resource "azurerm_network_interface_security_group_association" "vm_nic_nsg_association" {
  network_interface_id = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_virtual_machine" "vm" {
    name = var.VMName
    location = var.Location
    resource_group_name = azurerm_resource_group.resource_group.name
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
        key_data = file(var.AdminSSHKey)
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