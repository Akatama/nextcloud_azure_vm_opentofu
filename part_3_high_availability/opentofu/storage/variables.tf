// Used both by MySql/FlexibleServer and Storage Account
variable "ResourceBaseName" {
    type = string
    description = "The base name of the resource"
}

variable "ResourceGroupName" {
  type = string
  description = "Name of the resource group for the Database and the Blob Storage"
  default = "nextcloud-tofu-storage"
}

variable "Location" {
  type = string
  default = "Central US"
}

variable "VnetName" {
  type = string
}

variable "VnetResourceGroupName" {
  type = string
}

variable "DBSubnetName" {
    type = string
    default = "database"
}

variable "ServerSubnetName" {
    type = string
    default = "server"
}

// Used by MySql/FlexibleServer
variable "AdminUserName" {
  type = string
  description = "Administrator username for the DB"
}

variable "AdminPassword" {
    type = string
    description = "Administrator password for the DB"
}

variable "ServerEdition" {
    type = string
    description = "The tier of the particular SKU. Valid values are B for Burstable, GP for GeneralPurpose and MO for Memory Optimized. High Availability is available for GeneralPurpose and MemoryOptimized sku."
    default = "B"
}

variable "ServerVersion" {
    type = string
    description = "Valid values are 5.7 and 8.0.21"
    default = "8.0.21"
}

variable "AvailabilityZone" {
    type = string
    description = "Availability Zone info for the server. (Leave blank for no preference)."
    default = null
}

variable "HighAvailabilityMode" {
    type = string
    description = "High availability mode for a server : SameZone or ZoneRedundant"
    default = "SameZone"
}

variable "StandbyAvailabilityZone" {
    type = string
    description = "Availability zone of the standby server."
    default = "2"
}

variable "StorageSizeGB" {
    type = number
    default = 120
}

variable "StorageIOPS" {
    type = number
    default = 360
}

variable "StorageAutoGrow" {
    type = bool
    default = true
}

variable "DBSkuName" {
    type = string
    default = "Standard_B1ms"
    description = "The name of the sku, e.g. Standard_D32ds_v4."
}

variable "BackupRetentionDays" {
  type = number
  default = 7
}

variable "GeoRedundantBackup" {
    type = bool
    default = false
}

variable "DatabaseName" {
    type = string
    default = "nextcloud"
  
}

// Used by Storage Account

variable "StorageAccountTier" {
    type = string
    description = "Tier of the storage account. Valid values are Standard and Premium"
    default = "Standard"
}

variable "StorageReplicationType" {
    type = string
    description = "Defines the type of replication to use for this storage account. Valid options are LRS, GRS, RAGRS, ZRS, GZRS and RAGZRS"
    default = "LRS"
}

variable "StorageAccountKind" {
    type = string
    description = "The kind of storage that the storage account will use. Is limited to General-Purpose V2 for Standrad and BlockBlobStorage for Premium"
}