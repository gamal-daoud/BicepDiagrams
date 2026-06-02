// ============================================
// API MANAGEMENT AVEC BACKENDS
// APIM + Function Apps + App Services
// ============================================

param location string = resourceGroup().location
param apimName string = 'enterprise-apim'

// Log Analytics
resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: '${apimName}-logs'
  location: location
  properties: { sku: { name: 'PerGB2018' } }
}

// Application Insights pour APIM
resource apimInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${apimName}-insights'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logWorkspace.id
  }
}

// VNet pour APIM
resource apimVnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: '${apimName}-vnet'
  location: location
  properties: {
    addressSpace: { addressPrefixes: ['10.4.0.0/16'] }
    subnets: [
      {
        name: 'apim-subnet'
        properties: { addressPrefix: '10.4.1.0/24' }
      }
      {
        name: 'backend-subnet'
        properties: { addressPrefix: '10.4.2.0/24' }
      }
    ]
  }
}

// NSG pour APIM
resource apimNsg 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: '${apimName}-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowHttps'
        properties: {
          priority: 100
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRange: '443'
        }
      }
      {
        name: 'AllowManagement'
        properties: {
          priority: 110
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'ApiManagement'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRange: '3443'
        }
      }
    ]
  }
}

// Key Vault pour certificats APIM
resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: '${apimName}-kv-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    sku: { family: 'A', name: 'standard' }
    tenantId: subscription().tenantId
    enableSoftDelete: true
  }
}

// App Service Plan pour les backends
resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: '${apimName}-asp'
  location: location
  sku: { name: 'P1v3', tier: 'PremiumV3' }
  properties: { reserved: false }
}

// Backend 1 - Service Clients
resource clientsBackend 'Microsoft.Web/sites@2022-09-01' = {
  name: '${apimName}-clients-api'
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      netFrameworkVersion: 'v8.0'
      minTlsVersion: '1.2'
    }
  }
  dependsOn: [apimVnet]
}

// Backend 2 - Service Paiements
resource paymentsBackend 'Microsoft.Web/sites@2022-09-01' = {
  name: '${apimName}-payments-api'
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      netFrameworkVersion: 'v8.0'
      minTlsVersion: '1.2'
    }
  }
  dependsOn: [apimVnet]
}

// Backend 3 - Service Notifications
resource notificationsBackend 'Microsoft.Web/sites@2022-09-01' = {
  name: '${apimName}-notifications-api'
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      netFrameworkVersion: 'v8.0'
      minTlsVersion: '1.2'
    }
  }
  dependsOn: [apimVnet]
}

// SQL Server pour les backends
resource sqlServer 'Microsoft.Sql/servers@2022-05-01-preview' = {
  name: '${apimName}-sql-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    administratorLogin: 'sqladmin'
    administratorLoginPassword: 'P@ssw0rd123!'
    minimalTlsVersion: '1.2'
  }
}

// Base de données principale
resource mainDb 'Microsoft.Sql/servers/databases@2022-05-01-preview' = {
  parent: sqlServer
  name: 'enterprise-db'
  location: location
  sku: { name: 'S2', tier: 'Standard' }
  properties: { collation: 'SQL_Latin1_General_CP1_CI_AS' }
  dependsOn: [clientsBackend, paymentsBackend, notificationsBackend]
}

// Redis Cache pour APIM
resource redisCache 'Microsoft.Cache/redis@2023-04-01' = {
  name: '${apimName}-redis-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    sku: { name: 'Premium', family: 'P', capacity: 1 }
  }
  dependsOn: [mainDb]
}

output clientsApiUrl string = 'https://${clientsBackend.properties.defaultHostName}'
output paymentsApiUrl string = 'https://${paymentsBackend.properties.defaultHostName}'
output notificationsApiUrl string = 'https://${notificationsBackend.properties.defaultHostName}'
