@description('Specifies the private DNS zone name')
param privateDnsZoneName string

@description('Specifies the virtual network id')
param virtualNetworkId string

@description('Specifies whether to enable auto registration for private DNS.')
param autoRegistration bool = false

@description('Species the tags.')
param tags object = {}

// Variables
var location = 'global'

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateDnsZoneName
  location: location
}

resource vnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (length(virtualNetworkId) > 0) {
  parent: privateDnsZone
  name: '${privateDnsZoneName}-link'
  location: location
  tags: tags
  properties: {
    registrationEnabled: autoRegistration
    virtualNetwork: {
      id: virtualNetworkId
    }
  }
}

output id string = privateDnsZone.id
output name string = privateDnsZone.name
