targetScope = 'subscription'

@description('Name of the resource group.')
param resourceGroupName string

param location string = deployment().location

resource createResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
}
