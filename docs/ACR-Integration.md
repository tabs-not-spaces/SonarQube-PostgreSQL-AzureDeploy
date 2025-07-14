# Azure Container Registry (ACR) Support

This document describes the Azure Container Registry (ACR) integration for the SonarQube deployment.

## Overview

The solution now supports using Azure Container Registry (ACR) instead of Docker Hub for container images. This provides several benefits:

- **Private container registry**: Keep your container images in your Azure environment
- **Managed identity authentication**: No need to manage Docker Hub credentials in your deployments
- **Better security**: Images are stored in your Azure subscription with proper access controls
- **Reduced external dependencies**: Less reliance on Docker Hub rate limits and availability

## Components

### PowerShell Script: `scripts/Push-ImagesToACR.ps1`

This script automates the process of pulling images from Docker Hub and pushing them to your ACR:

- Pulls SonarQube and Caddy images from Docker Hub
- Tags them for your ACR
- Pushes them to your private ACR
- Handles authentication to both Docker Hub and ACR

### Bicep Updates

The Bicep templates have been updated to support:

- **Optional ACR usage**: Can still use Docker Hub if preferred
- **Managed identity**: Automatic creation and configuration for ACR access
- **Flexible ACR deployment**: Create new ACR or use existing one

## Usage

### Step 1: Prepare Your ACR

#### Option A: Create ACR with the deployment
Set the following parameters:
```json
{
  "useACR": { "value": true },
  "createACR": { "value": true },
  "acrName": { "value": "mysonarqubecr" }
}
```

#### Option B: Use existing ACR
If you already have an ACR in the same resource group:
```json
{
  "useACR": { "value": true },
  "createACR": { "value": false },
  "acrName": { "value": "your-existing-acr-name" }
}
```

### Step 2: Push Images to ACR

Run the PowerShell script to populate your ACR:

```powershell
.\scripts\Push-ImagesToACR.ps1 -ACRName "mysonarqubecr" -DockerHubUsername "myuser" -DockerHubPassword "mytoken"
```

Optional parameters:
- `-SonarQubeVersion`: Specify a different SonarQube version (default: "community")
- `-CaddyVersion`: Specify a different Caddy version (default: "alpine")
- `-Force`: Re-push images even if they already exist in ACR

### Step 3: Deploy with ACR

Use the updated parameters file `parameters/main-with-acr.parameters.json` or update your existing parameters:

```bash
az deployment group create \
  --resource-group rg-sonarqube \
  --template-file bicep/main.bicep \
  --parameters @parameters/main-with-acr.parameters.json
```

## Parameters

### New Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `useACR` | bool | false | Whether to use ACR instead of Docker Hub |
| `acrName` | string | "" | Name of the ACR (required if useACR is true) |
| `createACR` | bool | false | Create new ACR or use existing one |

### Modified Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `dockerHubUsername` | string | "" | Now optional (only needed if useACR is false) |
| `dockerHubPassword` | string | "" | Now optional (only needed if useACR is false) |

## Security Benefits

### Managed Identity Authentication

When using ACR, the solution:
1. Creates a user-assigned managed identity
2. Assigns the ACR Pull role to the identity
3. Configures the container group to use the identity for ACR authentication
4. No credentials stored in the deployment templates

### Reduced External Dependencies

- No Docker Hub rate limits
- Images stored in your Azure subscription
- Better control over image lifecycle and security scanning

## Example Workflows

### Development Environment
```json
{
  "useACR": { "value": false },
  "dockerHubUsername": { "value": "myuser" },
  "dockerHubPassword": { "value": "mytoken" }
}
```

### Production Environment
```json
{
  "useACR": { "value": true },
  "createACR": { "value": true },
  "acrName": { "value": "prodsonarqubecr" },
  "dockerHubUsername": { "value": "" },
  "dockerHubPassword": { "value": "" }
}
```

## Troubleshooting

### PowerShell Script Issues

1. **Docker not running**: Ensure Docker Desktop or Docker Engine is started
2. **Azure CLI not authenticated**: Run `az login` before running the script
3. **ACR access denied**: Ensure you have sufficient permissions on the ACR

### Deployment Issues

1. **Managed identity permissions**: The deployment automatically assigns ACR Pull permissions
2. **Image not found**: Ensure the images were successfully pushed to ACR using the PowerShell script
3. **ACR not accessible**: Check that the ACR exists and is in the same resource group

### Common Error Messages

- "Failed to pull image": Images might not exist in ACR or managed identity lacks permissions
- "ACR not found": Check ACR name and ensure it exists in the same resource group
- "Managed identity not found": This can happen if the deployment order is incorrect (should be automatic)

## Migration from Docker Hub

To migrate an existing deployment from Docker Hub to ACR:

1. Run the PowerShell script to populate your ACR
2. Update your parameter file to enable ACR usage
3. Redeploy the solution

The deployment will:
- Create a new managed identity
- Update the container group to use ACR
- Maintain all existing data and configuration