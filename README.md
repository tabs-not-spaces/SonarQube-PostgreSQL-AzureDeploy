# SonarQube-PostgreSQL-AzureDeploy

Bicep deployment files for a SonarQube deployment backed by a PostgreSQL database, deployed on Azure Container Instances with an Nginx reverse proxy.

## Quick Start

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Ftabs-not-spaces%2FSonarQube-PostgreSQL-AzureDeploy%2Fmain%2Fazuredeploy.json)

Click the button above to deploy directly to Azure. You'll be prompted to provide:
- PostgreSQL admin credentials  
- Docker Hub username and password/token
- Azure region and resource naming preferences

## Architecture

This deployment creates:
- **Azure PostgreSQL Flexible Server** - Database backend for SonarQube
- **Azure Container Instance Group** containing:
  - SonarQube Community Edition container
  - Nginx reverse proxy container
- **Azure Storage Account** - For persistent SonarQube data (optional)

## Prerequisites

1. Azure CLI installed and logged in
2. Bicep CLI installed
3. Docker Hub account (required for pulling images)
4. Azure subscription with appropriate permissions

## Docker Hub Requirements

Since Docker Hub now requires authentication to pull images, you'll need to provide:
- Docker Hub username
- Docker Hub password or Personal Access Token (recommended)

To create a Personal Access Token:
1. Log in to Docker Hub
2. Go to Account Settings > Security
3. Create a new Access Token
4. Use this token as the password parameter

## Deployment

### Manual Deployment

#### 1. Clone the repository
```bash
git clone https://github.com/tabs-not-spaces/SonarQube-PostgreSQL-AzureDeploy.git
cd SonarQube-PostgreSQL-AzureDeploy
```

#### 2. Update parameters
Edit `parameters/main.parameters.json` and update the following values:
- `postgresAdminPassword`: Strong password for PostgreSQL admin
- `dockerHubUsername`: Your Docker Hub username
- `dockerHubPassword`: Your Docker Hub password or Personal Access Token
- `location`: Azure region for deployment
- Other parameters as needed

#### 3. Create resource group
```bash
az group create --name rg-sonarqube --location "East US"
```

#### 4. Deploy the template
```bash
az deployment group create \
  --resource-group rg-sonarqube \
  --template-file bicep/main.bicep \
  --parameters @parameters/main.parameters.json
```

#### 5. Get deployment outputs
```bash
az deployment group show \
  --resource-group rg-sonarqube \
  --name main \
  --query properties.outputs
```

## Post-Deployment

1. The deployment will output the SonarQube URL
2. Initial login credentials are:
   - Username: `admin`
   - Password: `admin`
3. Change the default password on first login
4. Configure SonarQube projects and quality gates as needed

## Configuration

### PostgreSQL Settings
- **Version**: PostgreSQL 14
- **SKU**: Standard_B1ms (Burstable tier)
- **Storage**: 32GB with auto-grow enabled
- **Backup**: 7-day retention
- **Network**: Public access enabled with firewall rules

### Container Resources
- **CPU**: 2 cores total (1.5 for SonarQube, 0.5 for Nginx)
- **Memory**: 4GB total (3GB for SonarQube, 1GB for Nginx)
- **Networking**: Public IP with DNS label

### Security Considerations
- PostgreSQL has firewall rules allowing all IPs for Container Instances connectivity
- In production, consider:
  - Using Azure Virtual Network integration
  - Implementing private endpoints
  - Restricting firewall rules to specific IP ranges
  - Using Azure Key Vault for secrets
  - Enabling HTTPS with proper certificates

## Customization

### Scaling
Modify these parameters in the parameters file:
- `cpuCores`: Increase CPU allocation
- `memoryInGb`: Increase memory allocation
- PostgreSQL SKU in the postgresql.bicep module

### Versions
- `sonarQubeVersion`: Change SonarQube container tag
- `nginxVersion`: Change Nginx container tag
- `postgresVersion`: Change PostgreSQL version (in postgresql.bicep)

### Storage
The deployment includes an Azure Storage Account for potential persistent data storage. To use it:
1. Mount Azure File Shares to SonarQube containers
2. Modify the container-group.bicep to use azureFile volumes instead of emptyDir

## Monitoring and Logs

### Container Logs
```bash
az container logs --resource-group rg-sonarqube --name sonarqube-containers --container-name sonarqube
az container logs --resource-group rg-sonarqube --name sonarqube-containers --container-name nginx
```

### PostgreSQL Metrics
Monitor through Azure Portal or Azure Monitor:
- CPU utilization
- Memory usage
- Connection count
- Storage usage

## Troubleshooting

### Common Issues

1. **Container startup failures**
   - Check Docker Hub credentials
   - Verify container resource allocations
   - Review container logs

2. **Database connection issues**
   - Verify PostgreSQL firewall rules
   - Check connection string format
   - Confirm database credentials

3. **Nginx proxy issues**
   - Verify SonarQube container is running
   - Check port configurations
   - Review nginx logs

### Cleanup
To remove all resources:
```bash
az group delete --name rg-sonarqube --yes --no-wait
```

## Repository Structure

```
├── bicep/
│   ├── main.bicep                    # Main Bicep template
│   └── modules/
│       ├── postgresql.bicep          # PostgreSQL Flexible Server module
│       └── container-group.bicep     # Container Instance Group module
├── parameters/
│   ├── main.parameters.json          # Development parameters
│   └── production.parameters.json    # Production parameters example
├── azuredeploy.json                  # ARM template (generated from Bicep)
├── azuredeploy.parameters.json       # ARM parameters for Deploy button
├── deploy.sh                         # Automated deployment script
└── README.md                         # This file
```

> **Note**: The `azuredeploy.json` and `azuredeploy.parameters.json` files are generated from the Bicep templates to support the "Deploy to Azure" button functionality.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test the deployment
5. Submit a pull request

## License

This project is licensed under the MIT License.
