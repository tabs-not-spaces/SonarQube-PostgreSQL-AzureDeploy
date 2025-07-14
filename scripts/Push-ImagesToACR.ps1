#Requires -Version 5.1
<#
.SYNOPSIS
    Pulls Docker images from Docker Hub and pushes them to Azure Container Registry (ACR).

.DESCRIPTION
    This script pulls the required Docker images for SonarQube deployment from Docker Hub
    and pushes them to a specified Azure Container Registry. This enables the use of
    private container registries with managed identity authentication.

.PARAMETER ACRName
    The name of the Azure Container Registry (without .azurecr.io suffix).

.PARAMETER SonarQubeVersion
    The SonarQube image version/tag to pull and push. Default is 'community'.

.PARAMETER CaddyVersion
    The Caddy image version/tag to pull and push. Default is 'alpine'.

.PARAMETER DockerHubUsername
    Docker Hub username for authentication (required for pulling images).

.PARAMETER DockerHubPassword
    Docker Hub password or Personal Access Token for authentication.

.PARAMETER Force
    Force re-pull and re-push images even if they already exist in ACR.

.EXAMPLE
    .\Push-ImagesToACR.ps1 -ACRName "myacr" -DockerHubUsername "myuser" -DockerHubPassword "mytoken"

.EXAMPLE
    .\Push-ImagesToACR.ps1 -ACRName "myacr" -SonarQubeVersion "9.9.0-community" -CaddyVersion "2.7-alpine" -DockerHubUsername "myuser" -DockerHubPassword "mytoken"

.NOTES
    Prerequisites:
    - Docker Desktop or Docker Engine installed and running
    - Azure CLI installed and logged in with appropriate permissions
    - Access to both Docker Hub and the target ACR
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ACRName,

    [Parameter(Mandatory = $false)]
    [string]$SonarQubeVersion = "community",

    [Parameter(Mandatory = $false)]
    [string]$CaddyVersion = "alpine",

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$DockerHubUsername,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$DockerHubPassword,

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

# Global variables
$ACRLoginServer = "$ACRName.azurecr.io"
$Images = @(
    @{
        Name = "sonarqube"
        Version = $SonarQubeVersion
        SourceImage = "sonarqube:$SonarQubeVersion"
        TargetImage = "$ACRLoginServer/sonarqube:$SonarQubeVersion"
    },
    @{
        Name = "caddy"
        Version = $CaddyVersion
        SourceImage = "caddy:$CaddyVersion"
        TargetImage = "$ACRLoginServer/caddy:$CaddyVersion"
    }
)

function Write-LogMessage {
    param(
        [string]$Message,
        [ValidateSet("Info", "Warning", "Error", "Success")]
        [string]$Level = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "Info" { "White" }
        "Warning" { "Yellow" }
        "Error" { "Red" }
        "Success" { "Green" }
    }
    
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Test-DockerRunning {
    Write-LogMessage "Checking if Docker is running..."
    try {
        $null = docker version --format '{{.Server.Version}}' 2>$null
        Write-LogMessage "Docker is running" -Level "Success"
        return $true
    }
    catch {
        Write-LogMessage "Docker is not running or not accessible. Please start Docker Desktop or Docker Engine." -Level "Error"
        return $false
    }
}

function Test-AzureCLI {
    Write-LogMessage "Checking Azure CLI authentication..."
    try {
        $account = az account show --query "user.name" -o tsv 2>$null
        if ($account) {
            Write-LogMessage "Authenticated to Azure as: $account" -Level "Success"
            return $true
        }
        else {
            Write-LogMessage "Not authenticated to Azure. Please run 'az login'" -Level "Error"
            return $false
        }
    }
    catch {
        Write-LogMessage "Azure CLI is not installed or not in PATH" -Level "Error"
        return $false
    }
}

function Test-ACRAccess {
    param([string]$ACRName)
    
    Write-LogMessage "Checking access to ACR: $ACRName"
    try {
        $acrExists = az acr show --name $ACRName --query "name" -o tsv 2>$null
        if ($acrExists) {
            Write-LogMessage "ACR '$ACRName' is accessible" -Level "Success"
            return $true
        }
        else {
            Write-LogMessage "ACR '$ACRName' not found or not accessible" -Level "Error"
            return $false
        }
    }
    catch {
        Write-LogMessage "Failed to check ACR access: $_" -Level "Error"
        return $false
    }
}

function Connect-DockerHub {
    param(
        [string]$Username,
        [string]$Password
    )
    
    Write-LogMessage "Logging into Docker Hub..."
    try {
        $password | docker login docker.io --username $Username --password-stdin
        if ($LASTEXITCODE -eq 0) {
            Write-LogMessage "Successfully logged into Docker Hub" -Level "Success"
            return $true
        }
        else {
            Write-LogMessage "Failed to login to Docker Hub" -Level "Error"
            return $false
        }
    }
    catch {
        Write-LogMessage "Error logging into Docker Hub: $_" -Level "Error"
        return $false
    }
}

function Connect-ACR {
    param([string]$ACRName)
    
    Write-LogMessage "Logging into ACR: $ACRName"
    try {
        az acr login --name $ACRName
        if ($LASTEXITCODE -eq 0) {
            Write-LogMessage "Successfully logged into ACR" -Level "Success"
            return $true
        }
        else {
            Write-LogMessage "Failed to login to ACR" -Level "Error"
            return $false
        }
    }
    catch {
        Write-LogMessage "Error logging into ACR: $_" -Level "Error"
        return $false
    }
}

function Test-ImageExists {
    param(
        [string]$ImageName,
        [string]$ACRName
    )
    
    try {
        $tags = az acr repository show-tags --name $ACRName --repository $ImageName.Split(':')[0] --query "[]" -o tsv 2>$null
        $targetTag = $ImageName.Split(':')[1]
        return $tags -contains $targetTag
    }
    catch {
        return $false
    }
}

function Invoke-ImageOperations {
    param([hashtable]$Image)
    
    $imageName = "$($Image.Name):$($Image.Version)"
    
    # Check if image already exists in ACR (unless Force is specified)
    if (-not $Force) {
        if (Test-ImageExists -ImageName $imageName -ACRName $ACRName) {
            Write-LogMessage "Image $imageName already exists in ACR. Use -Force to overwrite." -Level "Warning"
            return $true
        }
    }
    
    Write-LogMessage "Processing image: $imageName"
    
    # Pull from Docker Hub
    Write-LogMessage "Pulling $($Image.SourceImage) from Docker Hub..."
    docker pull $Image.SourceImage
    if ($LASTEXITCODE -ne 0) {
        Write-LogMessage "Failed to pull $($Image.SourceImage)" -Level "Error"
        return $false
    }
    Write-LogMessage "Successfully pulled $($Image.SourceImage)" -Level "Success"
    
    # Tag for ACR
    Write-LogMessage "Tagging image for ACR..."
    docker tag $Image.SourceImage $Image.TargetImage
    if ($LASTEXITCODE -ne 0) {
        Write-LogMessage "Failed to tag image" -Level "Error"
        return $false
    }
    Write-LogMessage "Successfully tagged image as $($Image.TargetImage)" -Level "Success"
    
    # Push to ACR
    Write-LogMessage "Pushing $($Image.TargetImage) to ACR..."
    docker push $Image.TargetImage
    if ($LASTEXITCODE -ne 0) {
        Write-LogMessage "Failed to push $($Image.TargetImage)" -Level "Error"
        return $false
    }
    Write-LogMessage "Successfully pushed $($Image.TargetImage)" -Level "Success"
    
    # Clean up local tagged image (keep source image)
    Write-LogMessage "Cleaning up local tagged image..."
    docker rmi $Image.TargetImage 2>$null
    
    return $true
}

# Main execution
try {
    Write-LogMessage "Starting image push to ACR: $ACRName" -Level "Info"
    Write-LogMessage "SonarQube version: $SonarQubeVersion" -Level "Info"
    Write-LogMessage "Caddy version: $CaddyVersion" -Level "Info"
    
    # Prerequisites check
    if (-not (Test-DockerRunning)) { exit 1 }
    if (-not (Test-AzureCLI)) { exit 1 }
    if (-not (Test-ACRAccess -ACRName $ACRName)) { exit 1 }
    
    # Authentication
    if (-not (Connect-DockerHub -Username $DockerHubUsername -Password $DockerHubPassword)) { exit 1 }
    if (-not (Connect-ACR -ACRName $ACRName)) { exit 1 }
    
    # Process each image
    $successCount = 0
    foreach ($image in $Images) {
        if (Invoke-ImageOperations -Image $image) {
            $successCount++
        }
        else {
            Write-LogMessage "Failed to process $($image.Name):$($image.Version)" -Level "Error"
        }
    }
    
    # Summary
    Write-LogMessage "Completed processing $successCount of $($Images.Count) images" -Level "Info"
    
    if ($successCount -eq $Images.Count) {
        Write-LogMessage "All images successfully pushed to ACR: $ACRLoginServer" -Level "Success"
        Write-LogMessage "You can now update your Bicep templates to use these ACR images:" -Level "Info"
        foreach ($image in $Images) {
            Write-LogMessage "  - $($image.TargetImage)" -Level "Info"
        }
        exit 0
    }
    else {
        Write-LogMessage "Some images failed to process. Check the logs above for details." -Level "Error"
        exit 1
    }
}
catch {
    Write-LogMessage "Unexpected error: $_" -Level "Error"
    exit 1
}
finally {
    # Logout from Docker Hub for security
    Write-LogMessage "Logging out from Docker Hub..."
    docker logout docker.io 2>$null
}