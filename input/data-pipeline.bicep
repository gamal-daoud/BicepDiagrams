// ============================================
// PIPELINE DE DONNÉES AZURE
// Data Factory + Data Lake + Synapse Analytics
// ============================================

param location string = resourceGroup().location
param projectName string = 'datapipeline'

// Storage Account - Data Lake Gen2
resource dataLake 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: '${projectName}lake${uniqueString(resourceGroup().id)}'
  location: location
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: {
    isHnsEnabled: true
    accessTier: 'Hot'
  }
}

// Conteneur Raw Data
resource rawContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: '${dataLake.name}/default/raw'
  properties: { publicAccess: 'None' }
}

// Conteneur Processed Data
resource processedContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: '${dataLake.name}/default/processed'
  properties: { publicAccess: 'None' }
}

// Conteneur Curated Data
resource curatedContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: '${dataLake.name}/default/curated'
  properties: { publicAccess: 'None' }
}

// Log Analytics
resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: '${projectName}-logs'
  location: location
  properties: { sku: { name: 'PerGB2018' } }
}

// Key Vault pour les secrets
resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: '${projectName}-kv-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    sku: { family: 'A', name: 'standard' }
    tenantId: subscription().tenantId
    enableSoftDelete: true
  }
}

// Synapse Analytics Workspace
resource synapseWorkspace 'Microsoft.Synapse/workspaces@2021-06-01' = {
  name: '${projectName}-synapse'
  location: location
  identity: { type: 'SystemAssigned' }
  properties: {
    defaultDataLakeStorage: {
      accountUrl: dataLake.properties.primaryEndpoints.dfs
      filesystem: 'curated'
    }
    sqlAdministratorLogin: 'sqladmin'
    sqlAdministratorLoginPassword: 'P@ssw0rd123!'
  }
  dependsOn: [curatedContainer]
}

// Synapse SQL Pool dédié
resource sqlPool 'Microsoft.Synapse/workspaces/sqlPools@2021-06-01' = {
  parent: synapseWorkspace
  name: 'datawarehouse'
  location: location
  sku: { name: 'DW100c' }
  properties: { createMode: 'Default' }
}

// Azure Data Factory
resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' = {
  name: '${projectName}-adf-${uniqueString(resourceGroup().id)}'
  location: location
  identity: { type: 'SystemAssigned' }
  properties: {
    globalParameters: {
      environment: { type: 'String', value: 'production' }
    }
  }
  dependsOn: [rawContainer, processedContainer, curatedContainer]
}

// Application Insights pour Data Factory
resource adfInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${projectName}-adf-insights'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logWorkspace.id
  }
  dependsOn: [dataFactory]
}

output dataLakeEndpoint string = dataLake.properties.primaryEndpoints.dfs
output synapseEndpoint string = synapseWorkspace.properties.connectivityEndpoints.web
output dataFactoryId string = dataFactory.id
