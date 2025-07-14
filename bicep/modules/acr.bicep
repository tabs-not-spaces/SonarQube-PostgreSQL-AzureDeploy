@description('Location for the Azure Container Registry')
param location string

@description('Name of the Azure Container Registry')
param acrName string

@description('SKU for the Azure Container Registry')
@allowed(['Basic', 'Standard', 'Premium'])
param acrSku string = 'Standard'

@description('Enable admin user for the ACR')
param adminUserEnabled bool = false

@description('Tags to apply to resources')
param tags object = {}

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  tags: tags
  sku: {
    name: acrSku
  }
  properties: {
    adminUserEnabled: adminUserEnabled
    networkRuleSet: {
      defaultAction: 'Allow'
    }
    policies: {
      quarantinePolicy: {
        status: 'disabled'
      }
      trustPolicy: {
        type: 'Notary'
        status: 'disabled'
      }
      retentionPolicy: {
        days: 7
        status: 'disabled'
      }
      exportPolicy: {
        status: 'enabled'
      }
    }
    encryption: {
      status: 'disabled'
    }
    dataEndpointEnabled: false
    publicNetworkAccess: 'Enabled'
    networkRuleBypassOptions: 'AzureServices'
  }
}

@description('The resource ID of the ACR')
output acrId string = acr.id

@description('The name of the ACR')
output acrName string = acr.name

@description('The login server of the ACR')
output acrLoginServer string = acr.properties.loginServer