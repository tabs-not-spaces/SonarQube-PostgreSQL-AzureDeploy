#!/bin/bash

# SonarQube Azure Deployment Script
# This script simplifies the deployment process

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
RESOURCE_GROUP=""
LOCATION="East US"
PARAMETERS_FILE="parameters/main.parameters.json"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 -g <resource-group> [-l <location>] [-p <parameters-file>]"
    echo ""
    echo "Options:"
    echo "  -g, --resource-group    Azure resource group name (required)"
    echo "  -l, --location         Azure region (default: East US)"
    echo "  -p, --parameters       Parameters file path (default: parameters/main.parameters.json)"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 -g rg-sonarqube-prod -l \"West Europe\""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -g|--resource-group)
            RESOURCE_GROUP="$2"
            shift 2
            ;;
        -l|--location)
            LOCATION="$2"
            shift 2
            ;;
        -p|--parameters)
            PARAMETERS_FILE="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate required parameters
if [[ -z "$RESOURCE_GROUP" ]]; then
    print_error "Resource group name is required"
    show_usage
    exit 1
fi

if [[ ! -f "$PARAMETERS_FILE" ]]; then
    print_error "Parameters file not found: $PARAMETERS_FILE"
    exit 1
fi

print_status "Starting SonarQube deployment..."
print_status "Resource Group: $RESOURCE_GROUP"
print_status "Location: $LOCATION"
print_status "Parameters File: $PARAMETERS_FILE"

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    print_error "Azure CLI is not installed. Please install it first."
    exit 1
fi

# Check if Bicep CLI is installed
if ! command -v bicep &> /dev/null; then
    print_error "Bicep CLI is not installed. Please install it first."
    exit 1
fi

# Check if user is logged in to Azure
print_status "Checking Azure CLI login status..."
if ! az account show &> /dev/null; then
    print_error "Not logged in to Azure. Please run 'az login' first."
    exit 1
fi

# Validate the Bicep template
print_status "Validating Bicep template..."
if ! bicep build bicep/main.bicep; then
    print_error "Bicep template validation failed"
    exit 1
fi
print_status "Bicep template validation successful"

# Check if resource group exists
print_status "Checking if resource group exists..."
if ! az group show --name "$RESOURCE_GROUP" &> /dev/null; then
    print_status "Creating resource group: $RESOURCE_GROUP"
    az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
else
    print_status "Resource group already exists: $RESOURCE_GROUP"
fi

# Validate deployment parameters
print_status "Validating deployment parameters..."
az deployment group validate \
    --resource-group "$RESOURCE_GROUP" \
    --template-file bicep/main.bicep \
    --parameters "@$PARAMETERS_FILE"

if [[ $? -ne 0 ]]; then
    print_error "Parameter validation failed"
    exit 1
fi
print_status "Parameter validation successful"

# Deploy the template
print_status "Starting deployment (this may take 10-15 minutes)..."
DEPLOYMENT_NAME="sonarqube-deployment-$(date +%Y%m%d-%H%M%S)"

az deployment group create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DEPLOYMENT_NAME" \
    --template-file bicep/main.bicep \
    --parameters "@$PARAMETERS_FILE"

if [[ $? -ne 0 ]]; then
    print_error "Deployment failed"
    exit 1
fi

print_status "Deployment completed successfully!"

# Get deployment outputs
print_status "Retrieving deployment outputs..."
OUTPUTS=$(az deployment group show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DEPLOYMENT_NAME" \
    --query properties.outputs \
    --output json)

if [[ $? -eq 0 ]]; then
    echo ""
    echo "=== Deployment Outputs ==="
    echo "$OUTPUTS" | jq -r '
        "SonarQube URL: " + .sonarQubeUrl.value,
        "Public IP: " + .publicIpAddress.value,
        "PostgreSQL Server: " + .postgresServerFqdn.value
    '
    
    echo ""
    print_status "Default SonarQube credentials:"
    echo "  Username: admin"
    echo "  Password: admin"
    print_warning "Please change the default password after first login!"
    
else
    print_warning "Could not retrieve deployment outputs"
fi

print_status "Deployment script completed!"