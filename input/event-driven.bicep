// ============================================
// ARCHITECTURE EVENT-DRIVEN
// Service Bus + Event Grid + Azure Functions
// ============================================

param location string = resourceGroup().location
param projectName string = 'eventdriven'

// Log Analytics
resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: '${projectName}-logs'
  location: location
  properties: { sku: { name: 'PerGB2018' } }
}

// Application Insights
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${projectName}-insights'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logWorkspace.id
  }
}

// Storage Account pour les Functions
resource funcStorage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: '${projectName}stor${uniqueString(resourceGroup().id)}'
  location: location
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: { accessTier: 'Hot' }
}

// Blob Service
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: funcStorage
  name: 'default'
}

// Conteneur pour archivage des événements
resource archiveContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'event-archive'
  properties: { publicAccess: 'None' }
}

// Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: '${projectName}-kv-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    sku: { family: 'A', name: 'standard' }
    tenantId: subscription().tenantId
    enableSoftDelete: true
  }
}

// App Service Plan pour Functions
resource funcPlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: '${projectName}-func-plan'
  location: location
  sku: { name: 'Y1', tier: 'Dynamic' }
  properties: {}
}

// Function App - Producteur d'événements
resource producerFunc 'Microsoft.Web/sites@2022-09-01' = {
  name: '${projectName}-producer-func'
  location: location
  kind: 'functionapp'
  properties: {
    serverFarmId: funcPlan.id
    httpsOnly: true
    siteConfig: {
      appSettings: [
        { name: 'FUNCTIONS_WORKER_RUNTIME', value: 'dotnet' }
        { name: 'APPINSIGHTS_INSTRUMENTATIONKEY', value: appInsights.properties.InstrumentationKey }
        { name: 'AzureWebJobsStorage', value: 'DefaultEndpointsProtocol=https;AccountName=${funcStorage.name};AccountKey=${funcStorage.listKeys().keys[0].value}' }
      ]
    }
  }
}

// Function App - Consommateur Commandes
resource ordersConsumerFunc 'Microsoft.Web/sites@2022-09-01' = {
  name: '${projectName}-orders-func'
  location: location
  kind: 'functionapp'
  properties: {
    serverFarmId: funcPlan.id
    httpsOnly: true
    siteConfig: {
      appSettings: [
        { name: 'FUNCTIONS_WORKER_RUNTIME', value: 'dotnet' }
        { name: 'APPINSIGHTS_INSTRUMENTATIONKEY', value: appInsights.properties.InstrumentationKey }
        { name: 'AzureWebJobsStorage', value: 'DefaultEndpointsProtocol=https;AccountName=${funcStorage.name};AccountKey=${funcStorage.listKeys().keys[0].value}' }
      ]
    }
  }
  dependsOn: [producerFunc]
}

// Function App - Consommateur Notifications
resource notifConsumerFunc 'Microsoft.Web/sites@2022-09-01' = {
  name: '${projectName}-notif-func'
  location: location
  kind: 'functionapp'
  properties: {
    serverFarmId: funcPlan.id
    httpsOnly: true
    siteConfig: {
      appSettings: [
        { name: 'FUNCTIONS_WORKER_RUNTIME', value: 'dotnet' }
        { name: 'APPINSIGHTS_INSTRUMENTATIONKEY', value: appInsights.properties.InstrumentationKey }
        { name: 'AzureWebJobsStorage', value: 'DefaultEndpointsProtocol=https;AccountName=${funcStorage.name};AccountKey=${funcStorage.listKeys().keys[0].value}' }
      ]
    }
  }
  dependsOn: [producerFunc]
}

// CosmosDB pour persister les événements traités
resource cosmosDb 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  name: '${projectName}-cosmos-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    databaseAccountOfferType: 'Standard'
    locations: [{ locationName: location, failoverPriority: 0 }]
    consistencyPolicy: { defaultConsistencyLevel: 'Session' }
  }
  dependsOn: [ordersConsumerFunc, notifConsumerFunc]
}

output producerFuncUrl string = 'https://${producerFunc.properties.defaultHostName}'
output cosmoDbEndpoint string = cosmosDb.properties.documentEndpoint
