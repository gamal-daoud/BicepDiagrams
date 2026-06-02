// ============================================================================
// ARCHITECTURE SERVERLESS - TRAITEMENT DE DONNÉES EN TEMPS RÉEL
// ============================================================================

// ============================================================================
// PARAMÈTRES
// ============================================================================

@description('Environnement de déploiement')
@allowed(['dev', 'test', 'prod'])
param environment string = 'dev'

@description('Région Azure')
param location string = resourceGroup().location

@description('Nom du projet')
param projectName string = 'realtime-processor'

@description('Nombre de partitions pour Event Hub')
param eventHubPartitionCount int = 4

@description('Nombre de réplicas pour Container App')
param containerAppReplicas int = 2

// ============================================================================
// VARIABLES
// ============================================================================

var suffix = uniqueString(resourceGroup().id)
var commonTags = {
  Environment: environment
  Project: projectName
  ManagedBy: 'Bicep'
}

// Noms des ressources
var eventHubNamespaceName = 'eh-${projectName}-${environment}-${suffix}'
var eventHubName = 'telemetry-events'
var consumerGroupName = 'processor-group'
var serviceBusNamespaceName = 'sb-${projectName}-${environment}-${suffix}'
var serviceBusQueueName = 'processed-data'
var containerRegistryName = 'cr${projectName}${environment}${take(suffix, 5)}'
var containerAppEnvName = 'cae-${projectName}-${environment}'
var containerAppName = 'ca-processor-${environment}'
var storageAccountName = 'st${projectName}${environment}${take(suffix, 5)}'
var cosmosDbName = 'cosmos-${projectName}-${environment}-${suffix}'
var logAnalyticsName = 'law-${projectName}-${environment}'
var appInsightsName = 'ai-${projectName}-${environment}'
var keyVaultName = 'kv-${projectName}-${environment}-${suffix}'

// ============================================================================
// RESSOURCES - EVENT HUB
// ============================================================================

resource eventHubNamespace 'Microsoft.EventHub/namespaces@2023-01-01-preview' = {
  name: eventHubNamespaceName
  location: location
  tags: commonTags
  sku: {
    name: 'Standard'
    capacity: 1
  }
  properties: {
    isAutoInflateEnabled: true
    maximumThroughputUnits: 10
    zoneRedundant: false
    publicNetworkAccess: 'Enabled'
  }
}

resource telemetryEventHub 'Microsoft.EventHub/namespaces/eventhubs@2023-01-01-preview' = {
  parent: eventHubNamespace
  name: eventHubName
  properties: {
    messageRetentionInDays: 7
    partitionCount: eventHubPartitionCount
    status: 'Active'
  }
}

resource processorConsumerGroup 'Microsoft.EventHub/namespaces/eventhubs/consumergroups@2023-01-01-preview' = {
  parent: telemetryEventHub
  name: consumerGroupName
  properties: {
    userMetadata: 'Consumer group for processor container app'
  }
}

// ============================================================================
// RESSOURCES - SERVICE BUS
// ============================================================================

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' = {
  name: serviceBusNamespaceName
  location: location
  tags: commonTags
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
  properties: {
    zoneRedundant: false
    publicNetworkAccess: 'Enabled'
  }
}

resource serviceBusQueue 'Microsoft.ServiceBus/namespaces/queues@2022-10-01-preview' = {
  parent: serviceBusNamespace
  name: serviceBusQueueName
  properties: {
    lockDuration: 'PT1M'
    maxSizeInMegabytes: 1024
    requiresDuplicateDetection: false
    requiresSession: false
    defaultMessageTimeToLive: 'P14D'
    deadLetteringOnMessageExpiration: true
    maxDeliveryCount: 10
    status: 'Active'
    enableBatchedOperations: true
    enablePartitioning: false
  }
}

// ============================================================================
// RESSOURCES - STORAGE
// ============================================================================

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  tags: commonTags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Cool'
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
}

resource archiveContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'eventhub-archive'
  properties: {
    publicAccess: 'None'
  }
}

// ============================================================================
// RESSOURCES - COSMOS DB
// ============================================================================

resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2023-11-15' = {
  name: cosmosDbName
  location: location
  tags: commonTags
  kind: 'GlobalDocumentDB'
  properties: {
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    databaseAccountOfferType: 'Standard'
    enableAutomaticFailover: false
    enableMultipleWriteLocations: false
    publicNetworkAccess: 'Enabled'
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
  }
}

resource cosmosDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2023-11-15' = {
  parent: cosmosAccount
  name: 'telemetrydb'
  properties: {
    resource: {
      id: 'telemetrydb'
    }
  }
}

resource telemetryContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2023-11-15' = {
  parent: cosmosDatabase
  name: 'devices'
  properties: {
    resource: {
      id: 'devices'
      partitionKey: {
        paths: ['/deviceId']
        kind: 'Hash'
      }
      indexingPolicy: {
        indexingMode: 'consistent'
        includedPaths: [{path: '/*'}]
      }
      defaultTtl: 2592000
    }
  }
}

// ============================================================================
// RESSOURCES - CONTAINER REGISTRY
// ============================================================================

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: containerRegistryName
  location: location
  tags: commonTags
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
    publicNetworkAccess: 'Enabled'
  }
}

// ============================================================================
// RESSOURCES - MONITORING
// ============================================================================

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsName
  location: location
  tags: commonTags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  tags: commonTags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
    IngestionMode: 'LogAnalytics'
  }
}

// ============================================================================
// RESSOURCES - CONTAINER APP
// ============================================================================

resource containerAppEnv 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: containerAppEnvName
  location: location
  tags: commonTags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
    zoneRedundant: false
  }
}

resource containerApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: containerAppName
  location: location
  tags: commonTags
  properties: {
    environmentId: containerAppEnv.id
    configuration: {
      ingress: {
        external: false
        targetPort: 8080
        transport: 'auto'
        traffic: [{latestRevision: true, weight: 100}]
      }
      secrets: [
        {name: 'event-hub-connection-string', value: eventHubNamespace.listKeys().primaryConnectionString}
        {name: 'service-bus-connection-string', value: serviceBusNamespace.listKeys().primaryConnectionString}
        {name: 'cosmos-connection-string', value: cosmosAccount.listConnectionStrings().connectionStrings[0].connectionString}
      ]
    }
    template: {
      containers: [
        {
          name: 'processor'
          image: '${containerRegistry.properties.loginServer}/processor:latest'
          resources: {cpu: 0, memory: '1Gi'}
          env: [
            {name: 'EVENT_HUB_CONNECTION_STRING', secretRef: 'event-hub-connection-string'}
            {name: 'EVENT_HUB_NAME', value: eventHubName}
            {name: 'CONSUMER_GROUP', value: consumerGroupName}
            {name: 'SERVICE_BUS_CONNECTION_STRING', secretRef: 'service-bus-connection-string'}
            {name: 'SERVICE_BUS_QUEUE', value: serviceBusQueueName}
            {name: 'COSMOS_CONNECTION_STRING', secretRef: 'cosmos-connection-string'}
            {name: 'COSMOS_DATABASE', value: 'telemetrydb'}
            {name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: appInsights.properties.ConnectionString}
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: containerAppReplicas
      }
    }
  }
}

// ============================================================================
// RESSOURCES - KEY VAULT
// ============================================================================

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: keyVaultName
  location: location
  tags: commonTags
  properties: {
    sku: {family: 'A', name: 'standard'}
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    enablePurgeProtection: false
  }
}

// ============================================================================
// ALERTES
// ============================================================================

resource alertActionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: '${projectName}-alerts-${environment}'
  location: 'global'
  tags: commonTags
  properties: {
    groupShortName: 'RTAlerts'
    enabled: true
    emailReceivers: [
      {
        name: 'TeamEmail'
        emailAddress: 'data-platform@example.com'
        useCommonAlertSchema: true
      }
    ]
  }
}

resource highCpuAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: '${projectName}-high-cpu-${environment}'
  location: 'global'
  tags: commonTags
  properties: {
    description: 'Alert when CPU usage exceeds 80%'
    severity: 2
    enabled: true
    scopes: [containerApp.id]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HighCPU'
          metricName: 'CpuUsage'
          operator: 'GreaterThan'
          threshold: 80
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [{actionGroupId: alertActionGroup.id}]
  }
}

// ============================================================================
// OUTPUTS
// ============================================================================

output eventHubNamespaceOutput string = eventHubNamespace.name
output eventHubNameOutput string = telemetryEventHub.name
output serviceBusNamespaceOutput string = serviceBusNamespace.name
output serviceBusQueueOutput string = serviceBusQueue.name
output cosmosDbAccountOutput string = cosmosAccount.name
output storageAccountOutput string = storageAccount.name
output containerRegistryOutput string = containerRegistry.properties.loginServer
output keyVaultUriOutput string = keyVault.properties.vaultUri
output appInsightsConnectionStringOutput string = appInsights.properties.ConnectionString
