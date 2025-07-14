@description('Location for the container group')
param location string

@description('Name of the container group')
param containerGroupName string

@description('Docker Hub username (optional, used only if useACR is false)')
param dockerHubUsername string = ''

@secure()
@description('Docker Hub password/token (optional, used only if useACR is false)')
param dockerHubPassword string = ''

@description('Whether to use Azure Container Registry instead of Docker Hub')
param useACR bool = false

@description('ACR login server (required if useACR is true)')
param acrLoginServer string = ''

@description('Managed identity resource ID for ACR authentication (required if useACR is true)')
param managedIdentityId string = ''

@description('SonarQube container image version')
param sonarQubeVersion string = 'community'

@description('Caddy container image version')
param caddyVersion string = 'alpine'

@description('CPU cores for the container group')
param cpuCores int = 2

@description('Memory in GB for the container group')
param memoryInGb int = 4

@description('PostgreSQL server name')
param postgresServerName string

@description('PostgreSQL username')
param postgresUsername string

@secure()
@description('PostgreSQL password')
param postgresPassword string

@description('Database name')
param databaseName string

@description('Tags to apply to resources')
param tags object = {}

@description('Enable Azure Monitor logs for containers')
param enableAzureMonitorLogs bool = true

@description('Log Analytics workspace customer ID')
param logAnalyticsWorkspaceId string = ''

@secure()
@description('Log Analytics workspace primary shared key')
param logAnalyticsWorkspaceKey string = ''

// Caddy configuration will be provided via a simple approach
// since Container Instances don't support ConfigMaps like Kubernetes

// Determine image sources based on configuration
var sonarQubeImage = useACR ? '${acrLoginServer}/sonarqube:${sonarQubeVersion}' : 'sonarqube:${sonarQubeVersion}'
var caddyImage = useACR ? '${acrLoginServer}/caddy:${caddyVersion}' : 'caddy:${caddyVersion}'

resource containerGroup 'Microsoft.ContainerInstance/containerGroups@2023-05-01' = {
  name: containerGroupName
  location: location
  tags: tags
  identity: useACR ? {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}': {}
    }
  } : null
  properties: {
    osType: 'Linux'
    restartPolicy: 'Always'
    ipAddress: {
      type: 'Public'
      ports: [
        {
          protocol: 'TCP'
          port: 80
        }
      ]
      dnsNameLabel: '${containerGroupName}-${uniqueString(resourceGroup().id)}'
    }
    diagnostics: enableAzureMonitorLogs ? {
      logAnalytics: {
        workspaceId: logAnalyticsWorkspaceId
        workspaceKey: logAnalyticsWorkspaceKey
      }
    } : null
    imageRegistryCredentials: useACR ? [
      {
        server: acrLoginServer
        identity: managedIdentityId
      }
    ] : [
      {
        server: 'docker.io'
        username: dockerHubUsername
        password: dockerHubPassword
      }
    ]
    containers: [
      {
        name: 'sonarqube'
        properties: {
          image: sonarQubeImage
          resources: {
            requests: {
              cpu: cpuCores - 1
              memoryInGB: memoryInGb - 1
            }
          }
          ports: [
            {
              protocol: 'TCP'
              port: 9000
            }
          ]
          environmentVariables: [
            {
              name: 'SONAR_JDBC_URL'
              value: 'jdbc:postgresql://${postgresServerName}.postgres.database.azure.com:5432/${databaseName}?sslmode=require'
            }
            {
              name: 'SONAR_JDBC_USERNAME'
              value: postgresUsername
            }
            {
              name: 'SONAR_JDBC_PASSWORD'
              secureValue: postgresPassword
            }
            {
              name: 'SONAR_ES_BOOTSTRAP_CHECKS_DISABLE'
              value: 'true'
            }
          ]
          volumeMounts: [
            {
              name: 'sonarqube-conf'
              mountPath: '/opt/sonarqube/conf'
            }
            {
              name: 'sonarqube-data'
              mountPath: '/opt/sonarqube/data'
            }
            {
              name: 'sonarqube-logs'
              mountPath: '/opt/sonarqube/logs'
            }
            {
              name: 'sonarqube-extensions'
              mountPath: '/opt/sonarqube/extensions'
            }
          ]
        }
      }
      {
        name: 'caddy'
        properties: {
          image: caddyImage
          resources: {
            requests: {
              cpu: json('0.5')
              memoryInGB: 1
            }
          }
          ports: [
            {
              protocol: 'TCP'
              port: 80
            }
          ]
          command: [
            'caddy'
            'reverse-proxy'
            '--from'
            ':80'
            '--to'
            'localhost:9000'
          ]
        }
      }
    ]
    volumes: [
      {
        name: 'sonarqube-conf'
        azureFile: {
          shareName: 'conf'
          storageAccountName: storageAccount.name
          storageAccountKey: storageAccount.listKeys().keys[0].value
          readOnly: false
        }
      }
      {
        name: 'sonarqube-data'
        azureFile: {
          shareName: 'data'
          storageAccountName: storageAccount.name
          storageAccountKey: storageAccount.listKeys().keys[0].value
          readOnly: false
        }
      }
      {
        name: 'sonarqube-logs'
        azureFile: {
          shareName: 'logs'
          storageAccountName: storageAccount.name
          storageAccountKey: storageAccount.listKeys().keys[0].value
          readOnly: false
        }
      }
      {
        name: 'sonarqube-extensions'
        azureFile: {
          shareName: 'extensions'
          storageAccountName: storageAccount.name
          storageAccountKey: storageAccount.listKeys().keys[0].value
          readOnly: false
        }
      }
    ]
  }
}

// Create a storage account for persistent SonarQube data
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'sonarqube${uniqueString(resourceGroup().id)}'
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
  }
}

// Create file shares for SonarQube persistence
resource confFileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = {
  name: '${storageAccount.name}/default/conf'
  properties: {
    shareQuota: 1
  }
}

resource dataFileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = {
  name: '${storageAccount.name}/default/data'
  properties: {
    shareQuota: 10
  }
}

resource logsFileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = {
  name: '${storageAccount.name}/default/logs'
  properties: {
    shareQuota: 5
  }
}

resource extensionsFileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = {
  name: '${storageAccount.name}/default/extensions'
  properties: {
    shareQuota: 5
  }
}

// Deployment script to upload SonarQube configuration files
resource uploadConfigScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'upload-sonarqube-config'
  location: location
  tags: tags
  kind: 'AzureCLI'
  properties: {
    azCliVersion: '2.50.0'
    timeout: 'PT10M'
    retentionInterval: 'PT1H'
    environmentVariables: [
      {
        name: 'STORAGE_ACCOUNT_NAME'
        value: storageAccount.name
      }
      {
        name: 'STORAGE_ACCOUNT_KEY'
        secureValue: storageAccount.listKeys().keys[0].value
      }
    ]
    scriptContent: '''
# Create sonar.properties content
cat > sonar.properties << 'EOF'
# SonarQube Configuration for Container Deployment
# This file contains essential settings for running SonarQube in Azure Container Instances

# Disable memory mapping for Elasticsearch in containerized environments
# This is crucial for SonarQube to start properly in containers
sonar.search.javaAdditionalOpts=-Dnode.store.allow_mmap=false

# Set web context path (optional, defaults to /)
# sonar.web.context=/

# Set web port (optional, defaults to 9000)
# sonar.web.port=9000

# Additional JVM options for SonarQube server
# Optimize for container environment
sonar.web.javaAdditionalOpts=-Xmx2048m -Xms512m
EOF

# Upload sonar.properties to the conf file share
echo "Uploading sonar.properties to conf file share..."
az storage file upload \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --account-key "$STORAGE_ACCOUNT_KEY" \
    --share-name "conf" \
    --source "./sonar.properties" \
    --path "sonar.properties"

echo "Configuration files uploaded successfully!"
'''
  }
  dependsOn: [
    confFileShare
  ]
}

@description('The FQDN of the SonarQube application')
output sonarQubeUrl string = 'http://${containerGroup.properties.ipAddress.fqdn}'

@description('The public IP address of the container group')
output publicIpAddress string = containerGroup.properties.ipAddress.ip

@description('The container group name')
output containerGroupName string = containerGroup.name

@description('The storage account name used for persistence')
output storageAccountName string = storageAccount.name