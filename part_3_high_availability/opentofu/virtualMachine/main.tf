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

variable EnableDDoSProtection {
  type = bool
  default = false
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

resource "azurerm_availability_set" "availability_set" {
  name = "${var.VMName}-availabilityset"
  location = var.Location
  resource_group_name = azurerm_resource_group.resource_group.name
  platform_update_domain_count = var.ItemCount
  platform_fault_domain_count = var.ItemCount
  managed = true
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

resource "azurerm_public_ip" "public_IP" {
    count = var.ItemCount
    name = "${var.VMName}-PublicIP${count.index}"
    location = var.Location
    resource_group_name = azurerm_resource_group.resource_group.name
    sku = "Standard"
    allocation_method = "Static"
    idle_timeout_in_minutes = 4
    ip_version = "IPv4"
}

resource "azurerm_network_ddos_protection_plan" "ddos_protection" {
  count = var.EnableDDoSProtection ? 1 : 0
  name = "${var.VMName}-Prot"
  location = var.Location
  resource_group_name = azurerm_resource_group.resource_group.name
}

resource "azurerm_public_ip" "public_IP_LB" {
    name = "${var.VMName}-LB-PublicIP"
    location = var.Location
    resource_group_name = azurerm_resource_group.resource_group.name
    sku = "Standard"
    allocation_method = "Static"
    idle_timeout_in_minutes = 4
    ip_version = "IPv4"
    domain_name_label = lower("${var.VMName}-LB")
    zones = ["1", "2", "3"]
    ddos_protection_plan_id = var.EnableDDoSProtection ? azurerm_network_ddos_protection_plan.ddos_protection[0].id : null
    ddos_protection_mode = var.EnableDDoSProtection ? "Enabled" : "Disabled"
}

resource "azurerm_network_interface" "nic" {
  count = var.ItemCount
  name = "${var.VMName}-NIC${count.index}"
  location = var.Location
  resource_group_name = azurerm_resource_group.resource_group.name
  ip_configuration {
    name = "ipconfig1"
    private_ip_address_allocation = "Dynamic"
    subnet_id = data.azurerm_subnet.subnet.id
    public_ip_address_id = azurerm_public_ip.public_IP[count.index].id
  }
}

resource "azurerm_network_interface_security_group_association" "vm_nic_nsg_association" {
  count = var.ItemCount
  network_interface_id = azurerm_network_interface.nic[count.index].id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_lb" "load_balancer" {
  name = "${var.VMName}-LB"
  location = var.Location
  resource_group_name = azurerm_resource_group.resource_group.name
  sku = "Standard"
  frontend_ip_configuration {
    name                 = "LoadBalancerFrontend"
    public_ip_address_id = azurerm_public_ip.public_IP_LB.id
  }

}

resource "azurerm_lb_backend_address_pool" "backend_pool" {
  loadbalancer_id = azurerm_lb.load_balancer.id
  name            = "BackEndAddressPool"
}

resource "azurerm_lb_probe" "lb_probe" {
  loadbalancer_id = azurerm_lb.load_balancer.id
  name            = "lb_probe"
  port            = 80
  protocol = "Tcp"
  interval_in_seconds = 15
  number_of_probes = 2

}

resource "azurerm_lb_rule" "HTTPS_rule" {
  loadbalancer_id = azurerm_lb.load_balancer.id
  frontend_ip_configuration_name = azurerm_lb.load_balancer.frontend_ip_configuration[0].name
  backend_address_pool_ids = [azurerm_lb_backend_address_pool.backend_pool.id]
  probe_id = azurerm_lb_probe.lb_probe.id
  name                           = "lbHTTPS"
  protocol                       = "Tcp"
  frontend_port                  = 443
  backend_port                   = 443
  idle_timeout_in_minutes = 15
  load_distribution = "SourceIPProtocol"
}

resource "azurerm_lb_rule" "HTTP_rule" {
  loadbalancer_id = azurerm_lb.load_balancer.id
  frontend_ip_configuration_name = azurerm_lb.load_balancer.frontend_ip_configuration[0].name
  backend_address_pool_ids = [azurerm_lb_backend_address_pool.backend_pool.id]
  probe_id = azurerm_lb_probe.lb_probe.id
  name                           = "lbHTTP"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  idle_timeout_in_minutes = 15
  load_distribution = "SourceIPProtocol"
}


resource "azurerm_network_interface_backend_address_pool_association" "vm_nic_lb_association" {
  count = var.ItemCount
  network_interface_id    = azurerm_network_interface.nic[count.index].id
  ip_configuration_name   = "ipconfig1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.backend_pool.id
}


resource "azurerm_virtual_machine" "vm" {
    count = var.ItemCount
    name = "${var.VMName}-${count.index}"
    location = var.Location
    resource_group_name = azurerm_resource_group.resource_group.name
    availability_set_id = azurerm_availability_set.availability_set.id
    vm_size = var.VMSize
    delete_data_disks_on_termination = true
    delete_os_disk_on_termination = true
    network_interface_ids = [
        azurerm_network_interface.nic[count.index].id
    ]
    storage_os_disk {
        name = "${var.VMName}-OSDisk-${count.index}"
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
}