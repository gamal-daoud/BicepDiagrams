// ============================================
// SITE STATIQUE AVEC CDN AZURE
// Storage Static Website + Azure CDN + Front Door
// ============================================

param location string = resourceGroup().location
param siteName string = 'mystaticsite'

// Storage Account pour héberger le site statique
resource staticStorage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: '${siteName}${uniqueString(resourceGroup().id)}'
  location: location
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
  }
}

// Blob Service
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: staticStorage
  name: 'default'
}

// Conteneur $web pour héberger le site
resource webContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: '$web'
  properties: { publicAccess: 'Blob' }
}

// Conteneur pour les assets (images, vidéos)
resource assetsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'assets'
  properties: { publicAccess: 'Blob' }
}

// Log Analytics
resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: '${siteName}-logs'
  location: location
  properties: { sku: { name: 'PerGB2018' } }
}

// Application Insights pour monitoring du site
resource siteInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${siteName}-insights'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logWorkspace.id
  }
}

// Key Vault pour certificats SSL
resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: '${siteName}-kv-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    sku: { family: 'A', name: 'standard' }
    tenantId: subscription().tenantId
    enableSoftDelete: true
    enabledForDeployment: true
  }
}

// Auto Scale Settings pour monitoring
resource autoScale 'Microsoft.Insights/autoscalesettings@2022-10-01' = {
  name: '${siteName}-autoscale'
  location: location
  properties: {
    enabled: true
    targetResourceUri: staticStorage.id
    profiles: [{
      name: 'defaultProfile'
      capacity: { minimum: '1', maximum: '10', default: '1' }
      rules: []
    }]
  }
  dependsOn: [staticStorage, siteInsights]
}

output storageEndpoint string = staticStorage.properties.primaryEndpoints.web
output blobEndpoint string = staticStorage.properties.primaryEndpoints.blob
output insightsKey string = siteInsights.properties.InstrumentationKey
