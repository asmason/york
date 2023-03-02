
// Parameters
@description('Specifies the location for all resources.')
param location string

@description('Specifies the tags that you want to apply to all resources.')
param tags object = {}

@description('Specifies the name for the log analytics workspace.')
param logAnalyticsName string

// Resources
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: logAnalyticsName
  location: location
  tags: tags
  properties: {
    retentionInDays: 30
    sku: {
      name: 'PerGB2018'
    }
  }
}

// Outputs
output logAnalyticsId string = logAnalytics.id
