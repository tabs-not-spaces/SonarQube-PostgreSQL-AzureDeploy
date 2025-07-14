@description('Location for the PostgreSQL server')
param location string

@description('Name of the PostgreSQL server')
param serverName string

@description('Administrator username for PostgreSQL server')
param adminUsername string

@secure()
@description('Administrator password for PostgreSQL server')
param adminPassword string

@description('Name of the database to create')
param databaseName string

@description('Tags to apply to resources')
param tags object = {}

@description('PostgreSQL version')
param postgresVersion string = '14'

@description('SKU name for PostgreSQL server')
param skuName string = 'Standard_B1ms'

@description('SKU tier for PostgreSQL server')
param skuTier string = 'Burstable'

@description('Storage size in MB')
param storageSizeGB int = 32

resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2023-12-01-preview' = {
  name: serverName
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: skuTier
  }
  properties: {
    administratorLogin: adminUsername
    administratorLoginPassword: adminPassword
    version: postgresVersion
    storage: {
      storageSizeGB: storageSizeGB
      autoGrow: 'Enabled'
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    highAvailability: {
      mode: 'Disabled'
    }
    network: {
      publicNetworkAccess: 'Enabled'
    }
  }
}

// Create firewall rule to allow Azure services
resource firewallRuleAzure 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2023-12-01-preview' = {
  parent: postgresServer
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// Create firewall rule to allow all IPs (for Container Instances)
// Note: In production, you should restrict this to specific IP ranges
resource firewallRuleAll 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2023-12-01-preview' = {
  parent: postgresServer
  name: 'AllowAllIPs'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '255.255.255.255'
  }
}

// Create the SonarQube database
resource sonarQubeDatabase 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2023-12-01-preview' = {
  parent: postgresServer
  name: databaseName
  properties: {
    charset: 'UTF8'
    collation: 'en_US.utf8'
  }
}

@description('The name of the PostgreSQL server')
output serverName string = postgresServer.name

@description('The FQDN of the PostgreSQL server')
output serverFqdn string = postgresServer.properties.fullyQualifiedDomainName

@description('The database name')
output databaseName string = sonarQubeDatabase.name