// ============================================
// ARCHITECTURE IOT HUB
// IoT Hub + Stream Analytics + Time Series Insights
// ============================================

param location string = resourceGroup().location
param iotProjectName string = 'smartfactory'

// Log Analytics Workspace
resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: '${iotProjectName}-logs'
  location: location
  properties: { sku: { name: 'PerGB2018' } }
}

// Storage Account pour les données IoT brutes
resource iotStorage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: '${iotProjectName}stor${uniqueString(resourceGroup().id)}'
  location: location
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: { accessTier: 'Hot' }
}

// Blob Service
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: iotStorage
  name: 'default'
}

// Conteneur pour les télémétries
resource telemetryContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'telemetry'
  properties: { publicAccess: 'None' }
}

// Conteneur pour les alertes
resource alertsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'alerts'
  properties: { publicAccess: 'None' }
}

// VNet pour isoler l'infrastructure IoT
resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: '${iotProjectName}-vnet'
  location: location
  properties: {
    addressSpace: { addressPrefixes: ['10.3.0.0/16'] }
    subnets: [{
      name: 'iot-subnet'
      properties: { addressPrefix: '10.3.1.0/24' }
    }]
  }
}

// NSG pour la sécurité
resource nsg 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: '${iotProjectName}-nsg'
  location: location
  properties: {
    securityRules: [{
      name: 'AllowIoTHub'
      properties: {
        priority: 100
        protocol: 'Tcp'
        access: 'Allow'
        direction: 'Inbound'
        sourceAddressPrefix: '*'
        sourcePortRange: '*'
        destinationAddressPrefix: '*'
        destinationPortRange: '8883'
      }
    }]
  }
}

// Key Vault pour les secrets IoT
resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: '${iotProjectName}-kv-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    sku: { family: 'A', name: 'standard' }
    tenantId: subscription().tenantId
    enableSoftDelete: true
  }
}

// Application Insights pour monitoring IoT
resource iotInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${iotProjectName}-insights'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logWorkspace.id
  }
}

// CosmosDB pour stocker les données des capteurs
resource cosmosDb 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  name: '${iotProjectName}-cosmos-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    databaseAccountOfferType: 'Standard'
    locations: [{ locationName: location, failoverPriority: 0 }]
    consistencyPolicy: { defaultConsistencyLevel: 'Eventual' }
  }
  dependsOn: [telemetryContainer]
}

// Redis Cache pour les données temps réel
resource redisCache 'Microsoft.Cache/redis@2023-04-01' = {
  name: '${iotProjectName}-redis-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    sku: { name: 'Standard', family: 'C', capacity: 1 }
    enableNonSslPort: false
  }
  dependsOn: [cosmosDb]
}

output storageEndpoint string = iotStorage.properties.primaryEndpoints.blob
output cosmosDbEndpoint string = cosmosDb.properties.documentEndpoint
