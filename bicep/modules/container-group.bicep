@description('Location for the container group')
param location string

@description('Name of the container group')
param containerGroupName string

@description('Docker Hub username')
param dockerHubUsername string

@secure()
@description('Docker Hub password/token')
param dockerHubPassword string

@description('SonarQube container image version')
param sonarQubeVersion string = 'community'

@description('Nginx container image version')
param nginxVersion string = 'alpine'

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

// Nginx configuration will be provided via a simple approach
// since Container Instances don't support ConfigMaps like Kubernetes

resource containerGroup 'Microsoft.ContainerInstance/containerGroups@2023-05-01' = {
  name: containerGroupName
  location: location
  tags: tags
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
    imageRegistryCredentials: [
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
          image: 'sonarqube:${sonarQubeVersion}'
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
        name: 'nginx'
        properties: {
          image: 'nginx:${nginxVersion}'
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
            '/bin/sh'
            '-c'
            'echo "server { listen 80; server_name _; location / { proxy_pass http://localhost:9000; proxy_set_header Host \\$host; proxy_set_header X-Real-IP \\$remote_addr; proxy_set_header X-Forwarded-For \\$proxy_add_x_forwarded_for; proxy_set_header X-Forwarded-Proto \\$scheme; proxy_buffering off; proxy_request_buffering off; client_max_body_size 100M; } }" > /etc/nginx/conf.d/default.conf && nginx -g "daemon off;"'
          ]
        }
      }
    ]
    volumes: [
      {
        name: 'sonarqube-data'
        emptyDir: {}
      }
      {
        name: 'sonarqube-logs'
        emptyDir: {}
      }
      {
        name: 'sonarqube-extensions'
        emptyDir: {}
      }
    ]
  }
}

// Create a storage account for persistent SonarQube data (optional enhancement)
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

resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = {
  name: '${storageAccount.name}/default/sonarqube-data'
  properties: {
    shareQuota: 10
  }
}

@description('The FQDN of the SonarQube application')
output sonarQubeUrl string = 'http://${containerGroup.properties.ipAddress.fqdn}'

@description('The public IP address of the container group')
output publicIpAddress string = containerGroup.properties.ipAddress.ip

@description('The container group name')
output containerGroupName string = containerGroup.name