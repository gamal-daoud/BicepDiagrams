// ============================================
// ARCHITECTURE MULTI-RÉGION
// Traffic Manager + App Services dans plusieurs régions
// ============================================

param primaryLocation string = 'westeurope'
param secondaryLocation string = 'northeurope'
param appName string = 'global-app'

// ===== RÉGION PRIMAIRE =====

// Log Analytics Primaire
resource primaryLogs 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: '${appName}-primary-logs'
  location: primaryLocation
  properties: { sku: { name: 'PerGB2018' } }
}

// Application Insights Primaire
resource primaryInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${appName}-primary-insights'
  location: primaryLocation
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: primaryLogs.id
  }
}

// App Service Plan - Région Primaire
resource primaryPlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: '${appName}-primary-plan'
  location: primaryLocation
  sku: { name: 'P2v3', tier: 'PremiumV3' }
  properties: {}
}

// App Service - Région Primaire
resource primaryApp 'Microsoft.Web/sites@2022-09-01' = {
  name: '${appName}-primary-${uniqueString(resourceGroup().id)}'
  location: primaryLocation
  properties: {
    serverFarmId: primaryPlan.id
    httpsOnly: true
    siteConfig: {
      minTlsVersion: '1.2'
      alwaysOn: true
    }
  }
}

// SQL Server Primaire
resource primarySql 'Microsoft.Sql/servers@2022-05-01-preview' = {
  name: '${appName}-primary-sql-${uniqueString(resourceGroup().id)}'
  location: primaryLocation
  properties: {
    administratorLogin: 'sqladmin'
    administratorLoginPassword: 'P@ssw0rd123!'
  }
}

// Base de données Primaire
resource primaryDb 'Microsoft.Sql/servers/databases@2022-05-01-preview' = {
  parent: primarySql
  name: 'app-db-primary'
  location: primaryLocation
  sku: { name: 'S3', tier: 'Standard' }
  properties: { collation: 'SQL_Latin1_General_CP1_CI_AS' }
  dependsOn: [primaryApp]
}

// Règle Firewall SQL Primaire
resource primarySqlFirewall 'Microsoft.Sql/servers/firewallRules@2022-05-01-preview' = {
  parent: primarySql
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// ===== RÉGION SECONDAIRE =====

// Log Analytics Secondaire
resource secondaryLogs 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: '${appName}-secondary-logs'
  location: secondaryLocation
  properties: { sku: { name: 'PerGB2018' } }
}

// Application Insights Secondaire
resource secondaryInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${appName}-secondary-insights'
  location: secondaryLocation
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: secondaryLogs.id
  }
}

// App Service Plan - Région Secondaire
resource secondaryPlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: '${appName}-secondary-plan'
  location: secondaryLocation
  sku: { name: 'P2v3', tier: 'PremiumV3' }
  properties: {}
}

// App Service - Région Secondaire
resource secondaryApp 'Microsoft.Web/sites@2022-09-01' = {
  name: '${appName}-secondary-${uniqueString(resourceGroup().id)}'
  location: secondaryLocation
  properties: {
    serverFarmId: secondaryPlan.id
    httpsOnly: true
    siteConfig: {
      minTlsVersion: '1.2'
      alwaysOn: true
    }
  }
  dependsOn: [primaryApp]
}

// SQL Server Secondaire
resource secondarySql 'Microsoft.Sql/servers@2022-05-01-preview' = {
  name: '${appName}-secondary-sql-${uniqueString(resourceGroup().id)}'
  location: secondaryLocation
  properties: {
    administratorLogin: 'sqladmin'
    administratorLoginPassword: 'P@ssw0rd123!'
  }
  dependsOn: [primaryDb]
}

// Base de données Secondaire (réplica)
resource secondaryDb 'Microsoft.Sql/servers/databases@2022-05-01-preview' = {
  parent: secondarySql
  name: 'app-db-secondary'
  location: secondaryLocation
  sku: { name: 'S3', tier: 'Standard' }
  properties: { collation: 'SQL_Latin1_General_CP1_CI_AS' }
  dependsOn: [secondaryApp]
}

// Key Vault global
resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: '${appName}-kv-${uniqueString(resourceGroup().id)}'
  location: primaryLocation
  properties: {
    sku: { family: 'A', name: 'standard' }
    tenantId: subscription().tenantId
    enableSoftDelete: true
  }
  dependsOn: [primaryDb, secondaryDb]
}

// CosmosDB Multi-région pour la session
resource cosmosDb 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  name: '${appName}-cosmos-${uniqueString(resourceGroup().id)}'
  location: primaryLocation
  properties: {
    databaseAccountOfferType: 'Standard'
    locations: [
      { locationName: primaryLocation, failoverPriority: 0 }
      { locationName: secondaryLocation, failoverPriority: 1 }
    ]
    consistencyPolicy: { defaultConsistencyLevel: 'Session' }
    enableAutomaticFailover: true
  }
  dependsOn: [keyVault]
}

output primaryAppUrl string = 'https://${primaryApp.properties.defaultHostName}'
output secondaryAppUrl string = 'https://${secondaryApp.properties.defaultHostName}'
output cosmosEndpoint string = cosmosDb.properties.documentEndpoint
