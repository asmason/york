// Scope
targetScope = 'subscription'

// Parameters
@description('Location for the deployments and the resources')
param location string = deployment().location

@description('Provide the unique workspace name of exactly 4 chars. Used for naming resources.')
@maxLength(4)
@minLength(4)
param uniqueWorkspaceCode string

// Variables
var resourceGroupName = 'rg-prd-${uniqueWorkspaceCode}' 
var virtualNetworkName = 'vnet-prd-${uniqueWorkspaceCode}' 
var logWorkspaceName = 'law-prd-${uniqueWorkspaceCode}' 
var virtualNetworkAddressRange = '10.0.0.0/24'
var subnetAddressRange = '10.0.0.0/24'
var subnetName = 'snet-prd-${uniqueWorkspaceCode}' 
var storageAccountName = 'sa${substring(uniqueString(resourceGroupName), 0, 8)}${uniqueWorkspaceCode}' 
var subscriptionId = subscription().subscriptionId
var networkEndpointType = 'PrivateEndpoint'
var shareName = 'share01'
var subnets = [
  {
    name: subnetName
    addressPrefix: subnetAddressRange
  }
]

// Modules
module createResourceGroup './modules/resourcegroup/resource-group.bicep' = {
  name: 'createResourceGroup'
  params: {
    resourceGroupName: resourceGroupName
    location: location
  }
}

module logAnalytics './modules/loganalytics/log-analytics.bicep' = {
  scope: resourceGroup(subscriptionId, resourceGroupName)
  name: 'createLogAnalytics'
  params: {
    location: location
    logAnalyticsName:logWorkspaceName
  }
  dependsOn: [
    createResourceGroup
  ]
}

module createNetwork './modules/network/network.bicep' = {
  scope: resourceGroup(subscriptionId, resourceGroupName)
  name: 'createNetwork'
  params: {
    vnetAddressSpace: virtualNetworkAddressRange
    virtualNetworkName:virtualNetworkName
    existingLogWorkspaceResourceGroup:resourceGroupName
    existingLogWorkspaceName:logWorkspaceName
    subnets: subnets
    location: location
  }
  dependsOn: [
    createResourceGroup
    logAnalytics
  ]
}
resource existingVirtualNetwork 'Microsoft.Network/virtualNetworks@2021-03-01' existing  = {
  scope: resourceGroup(resourceGroupName)
  name: createNetwork.outputs.vnetName
}
resource existingSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' existing = {
  name: subnetName
  parent:existingVirtualNetwork
}

module createStorage './modules/storage/storage-account.bicep' = {
  scope: resourceGroup(subscriptionId, resourceGroupName)
  name:  'createStorageAccount'
  params: {
    location: location
    storageAccountName: storageAccountName
    networkEndpointType:networkEndpointType
    defaultToOAuthAuthentication:true
    shareNames:[shareName]
    virtualNetworkResourceGroupName:resourceGroupName
    virtualNetworkName:virtualNetworkName
    virtualNetworkSubnetName:subnetName
    existingLogWorkspaceResourceGroup: resourceGroupName
    existingLogWorkspaceName: logWorkspaceName
  }
  dependsOn: [
    createResourceGroup
  ]
}

module createPrivateDnsZoneFile './modules/private-dns-zone/private-dns-zone.bicep' =  {
  scope: resourceGroup(subscriptionId, resourceGroupName)
  name: 'createPrivateDnsZoneFile'
  params: {
    virtualNetworkId:createNetwork.outputs.vnetId
    privateDnsZoneName:'privatelink.file.${environment().suffixes.storage}' // file
  }
}

module createPrivateDnsZoneBlob './modules/private-dns-zone/private-dns-zone.bicep' =  {
  scope: resourceGroup(subscriptionId, resourceGroupName)
  name: 'createPrivateDnsZoneBlob'
  params: {
    virtualNetworkId:createNetwork.outputs.vnetId
    privateDnsZoneName:'privatelink.blob.${environment().suffixes.storage}' // blob
  }
}

module createPrivateEndpointBlob './modules/storage/private-endpoint.bicep' = if(networkEndpointType == 'PrivateEndpoint') {
  scope: resourceGroup(subscriptionId, resourceGroupName)
  name: 'createPrivateEndpointFileBlob'
  params: {
    location: location
    privateLinkServiceId:createStorage.outputs.storageId
    privateEndpointName:'pe-blob-${storageAccountName}'
    subnetId:existingSubnet.id
    groupName: 'blob'
    privateDnsZoneResourceGroupName:resourceGroupName
  }
  dependsOn:[createPrivateDnsZoneBlob]
}

module createPrivateEndpointFile './modules/storage/private-endpoint.bicep' = if(networkEndpointType == 'PrivateEndpoint') {
  scope: resourceGroup(subscriptionId, resourceGroupName)
  name: 'createPrivateEndpointFile'
  params: {
    location: location
    privateLinkServiceId:createStorage.outputs.storageId
    privateEndpointName:'pe-file-${storageAccountName}'
    subnetId:existingSubnet.id
    groupName: 'file'
    privateDnsZoneResourceGroupName:resourceGroupName
  }
  dependsOn:[createPrivateDnsZoneFile]
}

// Outputs
output provisionedSubscriptionId string = subscriptionId
output storageAccountId string = createStorage.outputs.storageId
output vnetId string = createNetwork.outputs.vnetId
output logAnalyticsId string = logAnalytics.outputs.logAnalyticsId
