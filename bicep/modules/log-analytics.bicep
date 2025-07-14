@description('Location for the Log Analytics workspace')
param location string

@description('Name of the Log Analytics workspace')
param workspaceName string

@description('Log retention in days (30-730)')
@minValue(30)
@maxValue(730)
param retentionInDays int = 30

@description('Pricing tier for Log Analytics workspace')
@allowed([
  'Free'
  'Standard'
  'Premium'
  'PerNode'
  'PerGB2018'
  'Standalone'
  'CapacityReservation'
])
param sku string = 'PerGB2018'

@description('Tags to apply to the Log Analytics workspace')
param tags object = {}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: workspaceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: sku
    }
    retentionInDays: retentionInDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    workspaceCapping: {
      dailyQuotaGb: json('-1')
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

@description('Log Analytics workspace resource ID')
output workspaceId string = logAnalyticsWorkspace.id

@description('Log Analytics workspace name')
output workspaceName string = logAnalyticsWorkspace.name

@description('Log Analytics workspace customer ID')
output workspaceCustomerId string = logAnalyticsWorkspace.properties.customerId

@description('Log Analytics workspace primary shared key')
output workspacePrimarySharedKey string = logAnalyticsWorkspace.listKeys().primarySharedKey