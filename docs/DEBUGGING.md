# Debugging Container Issues

This document explains how to debug container issues with the SonarQube deployment, especially after the restart policy has been changed to "Never" to prevent crash loops.

## Container Restart Policy

The container group is configured with `restartPolicy: "Never"` to prevent containers from continuously restarting when they encounter errors. This allows for better debugging by:

1. **Preventing crash loops** - Failed containers remain in a stopped state
2. **Preserving logs** - Container logs are retained and accessible for analysis
3. **Enabling debugging** - You can examine the failed container state and logs

## Accessing Container Logs

### Option 1: Azure Monitor Logs (Recommended)

The deployment includes an Azure Log Analytics workspace that automatically collects all container logs. Access logs through:

#### Azure Portal
1. Navigate to your resource group in the Azure Portal
2. Open the Log Analytics workspace (named `sonarqube-logs-{uniqueString}`)
3. Go to **Logs** section
4. Use these sample queries:

```kusto
// All container logs from the past hour
ContainerInstanceLog_CL 
| where TimeGenerated > ago(1h)
| order by TimeGenerated desc

// Error logs only
ContainerInstanceLog_CL 
| where LogSource_s == "stderr"
| order by TimeGenerated desc

// Logs for specific container
ContainerInstanceLog_CL 
| where ContainerName_s == "sonarqube"
| order by TimeGenerated desc

// Startup issues
ContainerInstanceLog_CL 
| where LogEntry_s contains "error" or LogEntry_s contains "fail"
| order by TimeGenerated desc
```

#### Azure CLI
```bash
# Query container logs
az monitor log-analytics query \
  --workspace <workspace-id> \
  --analytics-query "ContainerInstanceLog_CL | where ContainerGroup_s == 'your-container-group-name' | order by TimeGenerated desc"
```

### Option 2: Azure CLI Container Logs

```bash
# Get SonarQube container logs
az container logs \
  --resource-group <your-resource-group> \
  --name <container-group-name> \
  --container-name sonarqube

# Get Caddy proxy logs
az container logs \
  --resource-group <your-resource-group> \
  --name <container-group-name> \
  --container-name caddy

# Follow logs in real-time (if container is running)
az container logs \
  --resource-group <your-resource-group> \
  --name <container-group-name> \
  --container-name sonarqube \
  --follow
```

## Common Debugging Scenarios

### Container Won't Start

1. **Check container events**:
   ```bash
   az container show \
     --resource-group <your-resource-group> \
     --name <container-group-name> \
     --query "containers[].events"
   ```

2. **Review container logs** using Azure Monitor or CLI methods above

3. **Check container state**:
   ```bash
   az container show \
     --resource-group <your-resource-group> \
     --name <container-group-name> \
     --query "containers[].{name:name,state:instanceView.currentState}"
   ```

### Database Connection Issues

1. **Check PostgreSQL connectivity**:
   ```bash
   # Verify PostgreSQL server is running
   az postgres flexible-server show \
     --resource-group <your-resource-group> \
     --name <postgres-server-name>
   
   # Check firewall rules
   az postgres flexible-server firewall-rule list \
     --resource-group <your-resource-group> \
     --name <postgres-server-name>
   ```

2. **Test database connection** from another container or Azure Cloud Shell

### Resource Constraints

1. **Check resource allocation**:
   ```bash
   az container show \
     --resource-group <your-resource-group> \
     --name <container-group-name> \
     --query "containers[].{name:name,cpu:resources.requests.cpu,memory:resources.requests.memoryInGB}"
   ```

2. **Monitor resource usage** through Azure Monitor metrics

## Restarting After Debugging

Once you've identified and fixed the issue, you can restart the container group:

```bash
az container restart \
  --resource-group <your-resource-group> \
  --name <container-group-name>
```

Or if you need to change the restart policy back to "Always" for production use, update the Bicep template and redeploy.

## Log Retention

- Container logs are retained in Log Analytics for the configured retention period (default: 30 days)
- You can adjust retention in the `logRetentionInDays` parameter
- Azure CLI logs are available as long as the container exists

## Additional Resources

- [Azure Container Instances troubleshooting](https://docs.microsoft.com/en-us/azure/container-instances/container-instances-troubleshooting)
- [Azure Monitor for containers](https://docs.microsoft.com/en-us/azure/azure-monitor/insights/container-insights-overview)
- [Log Analytics query language (KQL)](https://docs.microsoft.com/en-us/azure/data-explorer/kusto/query/)