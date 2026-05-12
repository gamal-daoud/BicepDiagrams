param location string = resourceGroup().location

// 1. App Service Plan
resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: 'my-plan'
  location: location
  sku: {
    name: 'B1'
    tier: 'Basic'
  }
}

// 2. App Service (dépend du plan)
resource appService 'Microsoft.Web/sites@2022-03-01' = {
  name: 'myapp${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
  }
}

// 3. Storage Account
resource storage 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: 'mystorage${uniqueString(resourceGroup().id)}'
  location: location
  sku: {
    name: 'Standard_LRS' // Fichier Bicep simple et valide pour tester votre outil}
    kind: 'StorageV2'
  }

  // 4. Virtual Network
  resource vnet 'Microsoft.Network/virtualNetworks@2023-02-01' = {
    name: 'my-vnet'
    location: location
    properties: {
      addressSpace: { addressPrefixes: ['10.0.0.0/16'] }
    }
  }
output appServiceUrl string = 'https://${appService.name}.azurewebsites.net'
