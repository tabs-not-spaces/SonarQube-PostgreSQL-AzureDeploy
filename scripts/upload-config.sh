#!/bin/bash

# DEPRECATED: This script is no longer needed!
# The sonar.properties configuration is now automatically uploaded during Bicep deployment.
# This script is kept for reference only.

# Script to upload SonarQube configuration files to Azure File Share
# This script should be run after the Azure deployment is complete

set -e

# Function to display usage
show_usage() {
    echo "Usage: $0 -g <resource-group> -s <storage-account-name>"
    echo "  -g: Azure resource group name"
    echo "  -s: Storage account name"
    echo "Example: $0 -g rg-sonarqube -s sonarqubexxx"
}

# Parse command line arguments
while getopts "g:s:h" opt; do
    case $opt in
        g)
            RESOURCE_GROUP="$OPTARG"
            ;;
        s)
            STORAGE_ACCOUNT="$OPTARG"
            ;;
        h)
            show_usage
            exit 0
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            show_usage
            exit 1
            ;;
    esac
done

# Check if required parameters are provided
if [ -z "$RESOURCE_GROUP" ] || [ -z "$STORAGE_ACCOUNT" ]; then
    echo "Error: Missing required parameters"
    show_usage
    exit 1
fi

echo "Uploading SonarQube configuration files..."
echo "Resource Group: $RESOURCE_GROUP"
echo "Storage Account: $STORAGE_ACCOUNT"

# Get storage account key
echo "Retrieving storage account key..."
STORAGE_KEY=$(az storage account keys list \
    --resource-group "$RESOURCE_GROUP" \
    --account-name "$STORAGE_ACCOUNT" \
    --query '[0].value' \
    --output tsv)

if [ -z "$STORAGE_KEY" ]; then
    echo "Error: Could not retrieve storage account key"
    exit 1
fi

# Upload sonar.properties to the conf file share
echo "Uploading sonar.properties to conf file share..."
az storage file upload \
    --account-name "$STORAGE_ACCOUNT" \
    --account-key "$STORAGE_KEY" \
    --share-name "conf" \
    --source "./sonar.properties" \
    --path "sonar.properties"

echo "Configuration files uploaded successfully!"
echo ""
echo "You can now restart your container group to pick up the new configuration:"
echo "az container restart --resource-group $RESOURCE_GROUP --name <container-group-name>"