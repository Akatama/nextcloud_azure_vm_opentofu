#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Uses Ansible-Vault to get the password for the SQL Server admin
    Then calls the Bicep file to build the SQL server

.Example
    ./buildSQLServer.ps1 -ResourceBaseName nextCloudBicep -ResourceGroupName app-jlindsey2 -Location "Central US" -VNetName nextcloud-bicep-vnet -DBdminName ncadmin
#>
param(
    [Parameter(Mandatory=$true)][string]$ResourceBaseName,
    [Parameter(Mandatory=$true)][string]$ResourceGroupName,
    [Parameter(Mandatory=$true)][string]$Location,
    [Parameter(Mandatory=$true)][string]$VNetName,
    [Parameter(Mandatory=$true)][string]$VnetResourceGroup,
    [Parameter(Mandatory=$true)][string]$DBAdminName,
    [Parameter(Mandatory=$true)][string]$StorageAccountKind
)
$lowerResourceBaseName = "${ResourceBaseName}".ToLower()
$mySQlServerName = $lowerResourceBaseName

# Use Ansible-Vault to get the db password
$passwords = ansible-vault view ./ansible/nextcloud_passwords.enc --vault-password-file ./ansible/vault_pass
$DBAdminPassword = ConvertTo-SecureString $passwords[0].split(":")[1].trim() -AsPlainText -Force

Set-Location ./opentofu/storage

tofu apply -var ResourceBaseName="${ResourceBaseName}" -var ResourceGroupName="${ResourceGroupName}" -var Location="${Location}" `
    -var VnetName="${VNetName}" -var VnetResourceGroupName="${VnetResourceGroup}" -var AdminUserName="${DBAdminName}" `
    -var AdminPassword="${DBAdminPassword}" -var StorageAccountKind="${StorageAccountKind}" -var StorageAccountTier="Premium" `
    -var ServerEdition="GP" -var DBSkuName="Standard_D2ds_v4" -var GeoRedundantBackup="true" -var HighAvailabilityMode="SameZone" `
    -var AvailabilityZone="2" -auto-approve

Set-Location ../../

$requireSecureTransport = Update-AzMySqlFlexibleServerConfiguration -Name require_secure_transport -ResourceGroupName $ResourceGroupName `
    -ServerName $mySQlServerName -Value OFF

$dbYamlLine = "db_host: ${mySQlServerName}.mysql.database.azure.com"

$dbYamlLine > ./ansible/vars/db.yml