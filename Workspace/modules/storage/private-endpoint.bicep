// Scope
targetScope = 'resourceGroup'

// Parameters
@description('Specifies the location for all resources.')
param location string  = resourceGroup().location

@description('Specifies the tags.')
param tags object = {}

@description('Specifies the privateEndPointName')
param privateEndpointName string

@description('Specifies the private link service id')
param privateLinkServiceId string

@description('Specifies the subnet Id')
param subnetId string

@description('Specifies the private DNS Zone resource group id')
param privateDnsZoneResourceGroupName string

@description('Specifies the group name for the PE, e.g. file, blob, table,...')
param groupName string

// Variables
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2020-06-01' = {
  name: privateEndpointName
  location: location
  tags: tags
  properties: {
    privateLinkServiceConnections: [
      {
        name: privateEndpointName
        properties: {
          groupIds: [
            groupName
          ]
          privateLinkServiceId: privateLinkServiceId
        }
      }
    ]
    subnet: {
      id: subnetId
    }
  }
}

var privateDnsZoneName = 'privatelink.${groupName}.${environment().suffixes.storage}'

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  scope:resourceGroup(privateDnsZoneResourceGroupName)
  name: privateDnsZoneName
}

resource privateEndpointDns 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-06-01' = {
  name: '${privateEndpoint.name}/${groupName}-PrivateDnsZoneGroup'
  properties:{
    privateDnsZoneConfigs: [
      {
        name: privateDnsZoneName
        properties:{
          privateDnsZoneId: privateDnsZone.id
        }
      }
    ]
  }
}

