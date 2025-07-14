@description('Location for all resources')
param location string = resourceGroup().location

@description('Admin username for PostgreSQL server')
param postgresAdminUsername string

@secure()
@description('Admin password for PostgreSQL server')
param postgresAdminPassword string

@description('PostgreSQL server name')
param postgresServerName string = 'sonarqube-postgresql-${uniqueString(resourceGroup().id)}'

@description('Database name for SonarQube')
param databaseName string = 'sonarqube'

@description('Container group name')
param containerGroupName string = 'sonarqube-container-group'

@description('Docker Hub username (optional, used only if useACR is false)')
param dockerHubUsername string = ''

@secure()
@description('Docker Hub password/token (optional, used only if useACR is false)')
param dockerHubPassword string = ''

@description('Whether to use Azure Container Registry instead of Docker Hub')
param useACR bool = false

@description('Azure Container Registry name (required if useACR is true)')
param acrName string = ''

@description('Create new ACR or use existing ACR in the same resource group')
param createACR bool = false

@description('SonarQube version tag')
param sonarQubeVersion string = 'community'

@description('Caddy image tag')
param caddyVersion string = 'alpine'

@description('CPU cores for container group')
param cpuCores int = 2

@description('Memory in GB for container group')
param memoryInGb int = 4

@description('Tags to apply to all resources')
param tags object = {
  Application: 'SonarQube'
  Environment: 'Production'
}

// Deploy ACR if useACR is true and createACR is true
module acr 'modules/acr.bicep' = if (useACR && createACR) {
  name: 'acr-deployment'
  params: {
    location: location
    acrName: acrName
    tags: tags
  }
}

// Reference existing ACR if useACR is true but createACR is false
resource existingACR 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = if (useACR && !createACR) {
  name: acrName
}

// Deploy managed identity if useACR is true
module managedIdentity 'modules/managed-identity.bicep' = if (useACR) {
  name: 'managed-identity-deployment'
  params: {
    location: location
    identityName: '${containerGroupName}-identity'
    acrName: acrName
    tags: tags
  }
}

// Deploy PostgreSQL Flexible Server
module postgresql 'modules/postgresql.bicep' = {
  name: 'postgresql-deployment'
  params: {
    location: location
    serverName: postgresServerName
    adminUsername: postgresAdminUsername
    adminPassword: postgresAdminPassword
    databaseName: databaseName
    tags: tags
  }
}

// Deploy Container Group with SonarQube and Caddy
module containerGroup 'modules/container-group.bicep' = {
  name: 'container-group-deployment'
  params: {
    location: location
    containerGroupName: containerGroupName
    dockerHubUsername: dockerHubUsername
    dockerHubPassword: dockerHubPassword
    useACR: useACR
    acrLoginServer: useACR ? (createACR ? acr.outputs.acrLoginServer : existingACR.properties.loginServer) : ''
    managedIdentityId: useACR ? managedIdentity.outputs.identityId : ''
    sonarQubeVersion: sonarQubeVersion
    caddyVersion: caddyVersion
    cpuCores: cpuCores
    memoryInGb: memoryInGb
    postgresServerName: postgresql.outputs.serverName
    postgresUsername: postgresAdminUsername
    postgresPassword: postgresAdminPassword
    databaseName: databaseName
    tags: tags
  }
  dependsOn: useACR ? [managedIdentity] : []
}

@description('PostgreSQL server FQDN')
output postgresServerFqdn string = postgresql.outputs.serverFqdn

@description('Container group FQDN')
output sonarQubeUrl string = containerGroup.outputs.sonarQubeUrl

@description('Container group public IP')
output publicIpAddress string = containerGroup.outputs.publicIpAddress

@description('Storage account name for persistence')
output storageAccountName string = containerGroup.outputs.storageAccountName

@description('ACR login server (if ACR is used)')
output acrLoginServer string = useACR ? (createACR ? acr.outputs.acrLoginServer : existingACR.properties.loginServer) : ''

@description('Managed identity client ID (if ACR is used)')
output managedIdentityClientId string = useACR ? managedIdentity.outputs.clientId : ''