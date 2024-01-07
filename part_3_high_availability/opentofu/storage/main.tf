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

data "azurerm_subnet" "db_subnet" {
  name = var.DBSubnetName
  virtual_network_name = var.VnetName
  resource_group_name = var.VnetResourceGroupName
}

data "azurerm_subnet" "server_subnet" {
  name = var.ServerSubnetName
  virtual_network_name = var.VnetName
  resource_group_name = var.VnetResourceGroupName
}

data "azurerm_virtual_network" "vnet" {
    name = var.VnetName
    resource_group_name = var.VnetResourceGroupName
}

resource "azurerm_resource_group" "resource_group" {
    name = var.ResourceGroupName
    location = var.Location
}

# resource "azurerm_private_dns_zone" "dns_zone" {
#   name                = "${lower(var.ResourceBaseName)}.mysql.database.azure.com"
#   resource_group_name = azurerm_resource_group.resource_group.name
# }

# resource "azurerm_private_dns_zone_virtual_network_link" "dns_zone_link" {
#   name                  = "exampleVnetZone.com"
#   private_dns_zone_name = azurerm_private_dns_zone.dns_zone.name
#   virtual_network_id    = data.azurerm_virtual_network.vnet.id
#   resource_group_name   = azurerm_resource_group.resource_group.name
# }

resource "azurerm_mysql_flexible_server" "mysql_server" {
    name = "${lower(var.ResourceBaseName)}"
    resource_group_name = azurerm_resource_group.resource_group.name
    location = var.Location
    
    sku_name = "${var.ServerEdition}_${var.DBSkuName}"
    version = var.ServerVersion
    administrator_login = var.AdminUserName
    administrator_password = var.AdminPassword
    zone = var.AvailabilityZone

    high_availability {
        mode = var.HighAvailabilityMode != "Disabled" ? var.HighAvailabilityMode : null
        standby_availability_zone = var.HighAvailabilityMode != "Disabled" ? var.StandbyAvailabilityZone : null
    }
    storage {
        size_gb = var.StorageSizeGB
        iops = var.StorageIOPS
        auto_grow_enabled = var.StorageAutoGrow
    }
    delegated_subnet_id = data.azurerm_subnet.db_subnet.id
    
    backup_retention_days = var.BackupRetentionDays
    geo_redundant_backup_enabled = var.GeoRedundantBackup
}

resource "azurerm_mysql_flexible_database" "nextcloud" {
    name = var.DatabaseName
    resource_group_name = azurerm_resource_group.resource_group.name
    server_name = azurerm_mysql_flexible_server.mysql_server.name
    charset = "utf8mb4"
    collation = "utf8mb4_general_ci"
}

resource "azurerm_storage_account" "storage_account" {
    name = "${var.ResourceBaseName}storage"
    location = var.Location
    resource_group_name = azurerm_resource_group.resource_group.name

    account_tier = var.StorageAccountTier
    account_replication_type = var.StorageReplicationType

    account_kind = var.StorageAccountKind

    cross_tenant_replication_enabled = false
    allowed_copy_scope = "AAD"
    is_hns_enabled = true
    nfsv3_enabled = true
    sftp_enabled = true
    min_tls_version = "TLS1_2"

    network_rules {
        default_action = "Deny"
        bypass = toset(["AzureServices"])
        virtual_network_subnet_ids = [data.azurerm_subnet.server_subnet.id]
    }

    public_network_access_enabled = true

    routing {
        choice = "MicrosoftRouting"
    }
    enable_https_traffic_only = true
}