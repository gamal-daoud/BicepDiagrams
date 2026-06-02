
param location string = resourceGroup().location

// 1. Storage Account
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'st${uniqueString(resourceGroup().id)}'
  location: location
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
}

// 2. Blob Service
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
}

// 3. Container
resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'images'
}

// 4. App Service Plan
resource appPlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: 'plan${uniqueString(resourceGroup().id)}'
  location: location
  sku: { name: 'S1' }
}

// 5. Web App
resource webApp 'Microsoft.Web/sites@2023-01-01' = {
  name: 'app${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    serverFarmId: appPlan.id
    siteConfig: { linuxFxVersion: 'NODE|18-lts' }
  }
}
