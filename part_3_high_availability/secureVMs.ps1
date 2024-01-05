#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Generates a public and private SSH key
    Then passes it to the Bicep file in this repo to create a virtual machine scale set that we can access with that key

.DESCRIPTION
    Generates a public and private SSH key
    Then passes it to the Bicep file in this repo to create a virtual machine scale set that we can access with that key

.Example
    ./secureVMs.ps1 -ResourceBaseName nextCloudBicep -ResourceGroupName app-jlindsey2 -NumberOfInstances 3
#>
param(
    [Parameter(Mandatory=$true)][string]$ResourceBaseName,
    [Parameter(Mandatory=$true)][string]$ResourceGroupName,
    [Parameter(Mandatory=$true)][int]$NumberOfInstances
)

$nsgName = "${ResourceBaseName}-NSG"
$nicBaseName = "${ResourceBaseName}-NIC"
$publicIPBaseName = "${ResourceBaseName}-PublicIP"

# remove the SSH rule from the NSG
$nsg = Get-AzNetworkSecurityGroup -Name $nsgName -ResourceGroupName $ResourceGroupName
Remove-AzNetworkSecurityRuleConfig -Name SSH -NetworkSecurityGroup $nsg
Set-AzNetworkSecurityGroup -NetworkSecurityGroup $nsg


# Dissociate the Public IP from the NIC
# Then Delete the Public IP 
for($i=0; $i -lt 3; $i++)
{
    $nic = Get-AzNetworkInterface -Name "${nicBaseName}${i}" -ResourceGroupName $ResourceGroupName
    $nic.IpConfigurations[0].PublicIpAddress = $null
    Set-AzNetworkInterface -NetworkInterface $nic

    Remove-AzPublicIpAddress -Name "${publicIPBaseName}${i}" -ResourceGroupName $ResourceGroupName -Force
}