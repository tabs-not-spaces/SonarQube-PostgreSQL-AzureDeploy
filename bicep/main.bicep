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

@description('Docker Hub username')
param dockerHubUsername string

@secure()
@description('Docker Hub password/token')
param dockerHubPassword string

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
}

@description('PostgreSQL server FQDN')
output postgresServerFqdn string = postgresql.outputs.serverFqdn

@description('Container group FQDN')
output sonarQubeUrl string = containerGroup.outputs.sonarQubeUrl

@description('Container group public IP')
output publicIpAddress string = containerGroup.outputs.publicIpAddress