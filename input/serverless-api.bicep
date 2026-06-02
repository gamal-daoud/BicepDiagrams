// ============================================
// API SERVERLESS AVEC AZURE FUNCTIONS
// Functions + API Management + CosmosDB + Key Vault
// ============================================

param location string = resourceGroup().location
param appName string = 'serverless-api'

// Log Analytics
resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: '${appName}-logs'
  location: location
  properties: { sku: { name: 'PerGB2018' } }
}

// Application Insights
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${appName}-insights'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logWorkspace.id
  }
}

// Storage Account pour les Functions
resource funcStorage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: '${replace(appName, '-', '')}${uniqueString(resourceGroup().id)}'
  location: location
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
}

// Blob Service
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: funcStorage
  name: 'default'
}

// Conteneur pour les artefacts de déploiement
resource deployContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'deployments'
  properties: { publicAccess: 'None' }
}

// Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: '${appName}-kv-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    sku: { family: 'A', name: 'standard' }
    tenantId: subscription().tenantId
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
  }
}

// App Service Plan Consumption (Serverless)
resource consumptionPlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: '${appName}-plan'
  location: location
  sku: { name: 'Y1', tier: 'Dynamic' }
  properties: {}
}

// Function App - CRUD Users
resource usersFunctionApp 'Microsoft.Web/sites@2022-09-01' = {
  name: '${appName}-users'
  location: location
  kind: 'functionapp'
  identity: { type: 'SystemAssigned' }
  properties: {
    serverFarmId: consumptionPlan.id
    httpsOnly: true
    siteConfig: {
      appSettings: [
        { name: 'FUNCTIONS_EXTENSION_VERSION', value: '~4' }
        { name: 'FUNCTIONS_WORKER_RUNTIME', value: 'node' }
        { name: 'WEBSITE_NODE_DEFAULT_VERSION', value: '~18' }
        { name: 'APPINSIGHTS_INSTRUMENTATIONKEY', value: appInsights.properties.InstrumentationKey }
        { name: 'AzureWebJobsStorage', value: 'DefaultEndpointsProtocol=https;AccountName=${funcStorage.name};AccountKey=${funcStorage.listKeys().keys[0].value}' }
      ]
    }
  }
}

// Function App - CRUD Products
resource productsFunctionApp 'Microsoft.Web/sites@2022-09-01' = {
  name: '${appName}-products'
  location: location
  kind: 'functionapp'
  identity: { type: 'SystemAssigned' }
  properties: {
    serverFarmId: consumptionPlan.id
    httpsOnly: true
    siteConfig: {
      appSettings: [
        { name: 'FUNCTIONS_EXTENSION_VERSION', value: '~4' }
        { name: 'FUNCTIONS_WORKER_RUNTIME', value: 'node' }
        { name: 'WEBSITE_NODE_DEFAULT_VERSION', value: '~18' }
        { name: 'APPINSIGHTS_INSTRUMENTATIONKEY', value: appInsights.properties.InstrumentationKey }
        { name: 'AzureWebJobsStorage', value: 'DefaultEndpointsProtocol=https;AccountName=${funcStorage.name};AccountKey=${funcStorage.listKeys().keys[0].value}' }
      ]
    }
  }
}

// Function App - Orders Processing
resource ordersFunctionApp 'Microsoft.Web/sites@2022-09-01' = {
  name: '${appName}-orders'
  location: location
  kind: 'functionapp'
  identity: { type: 'SystemAssigned' }
  properties: {
    serverFarmId: consumptionPlan.id
    httpsOnly: true
    siteConfig: {
      appSettings: [
        { name: 'FUNCTIONS_EXTENSION_VERSION', value: '~4' }
        { name: 'FUNCTIONS_WORKER_RUNTIME', value: 'node' }
        { name: 'WEBSITE_NODE_DEFAULT_VERSION', value: '~18' }
        { name: 'APPINSIGHTS_INSTRUMENTATIONKEY', value: appInsights.properties.InstrumentationKey }
        { name: 'AzureWebJobsStorage', value: 'DefaultEndpointsProtocol=https;AccountName=${funcStorage.name};AccountKey=${funcStorage.listKeys().keys[0].value}' }
      ]
    }
  }
}

// CosmosDB pour la persistance
resource cosmosDb 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  name: '${appName}-cosmos-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    databaseAccountOfferType: 'Standard'
    locations: [{ locationName: location, failoverPriority: 0 }]
    consistencyPolicy: { defaultConsistencyLevel: 'Session' }
    enableServerlessCapacity: true
  }
  dependsOn: [usersFunctionApp, productsFunctionApp, ordersFunctionApp]
}

// Auto Scale settings
resource funcAutoScale 'Microsoft.Insights/autoscalesettings@2022-10-01' = {
  name: '${appName}-autoscale'
  location: location
  properties: {
    enabled: true
    targetResourceUri: consumptionPlan.id
    profiles: [{
      name: 'defaultProfile'
      capacity: { minimum: '0', maximum: '200', default: '1' }
      rules: []
    }]
  }
  dependsOn: [cosmosDb]
}

output usersApiUrl string = 'https://${usersFunctionApp.properties.defaultHostName}/api'
output productsApiUrl string = 'https://${productsFunctionApp.properties.defaultHostName}/api'
output ordersApiUrl string = 'https://${ordersFunctionApp.properties.defaultHostName}/api'
output cosmosDbEndpoint string = cosmosDb.properties.documentEndpoint
