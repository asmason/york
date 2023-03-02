// Parameters
param location string = resourceGroup().location

param virtualNetworkName string

param vnetAddressSpace string

param existingLogWorkspaceResourceGroup string

param existingLogWorkspaceName string

@description('Specifies an array of subnets including their name and address space.')
param subnets array

param dnsServers array = [
  //empty
]

// Resources
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2021-03-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressSpace
      ]
    }
    dhcpOptions: {
      dnsServers: dnsServers
    }
    subnets: [for (subnet, i) in subnets: {
      name: '${subnet.name}'
      properties: {
        addressPrefix: subnet.addressPrefix
        serviceEndpoints: []
        routeTable:  json('{"id":"${routeTables[i].id}"}')
        networkSecurityGroup: json('{"id":"${nsgs[i].id}"}')
      }
    }]
  }
}

// Empty Route tables
resource routeTables 'Microsoft.Network/routeTables@2021-05-01' = [for (subnet, i) in subnets: {
  name: 'rt-${subnet.name}'
  location: location
  properties: {
    routes: []
  }
}]

// Empty NSGs
resource nsgs 'Microsoft.Network/networkSecurityGroups@2021-05-01' = [for (subnet, i) in subnets:  {
  name: 'nsg-${subnet.name}'
  location: location
  properties: {
    securityRules: []
  }
}]

resource nsgDiags 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = [for (subnet, i) in subnets:  {
  scope: nsgs[i]
  name: 'default'
  properties: {
    workspaceId: existingLogAnalyticsWorkspace.id
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
  }
}]

resource existingLogAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  scope: resourceGroup(existingLogWorkspaceResourceGroup)
  name: existingLogWorkspaceName
}

resource nsg_rule_default_deny_internet_inbound 'Microsoft.Network/networkSecurityGroups/securityRules@2021-05-01' = [for (subnet, i) in subnets: {
  name: 'DenyInternetIn'
  parent: nsgs[i]
  properties: {
    description: 'Denies all inbound traffic from the Internet.'
    protocol: '*'
    sourcePortRange: '*'
    destinationPortRange: '*'
    sourceAddressPrefix: 'Internet'
    destinationAddressPrefix: '*'
    access: 'Deny'
    priority: 4096
    direction: 'Inbound'
  }
}]

output vnetId string = virtualNetwork.id
output vnetName string = virtualNetwork.name
output subnets array = virtualNetwork.properties.subnets
