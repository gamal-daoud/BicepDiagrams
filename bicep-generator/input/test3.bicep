// ============================================================================
// INFRASTRUCTURE BICEP POUR ENTREPRISE - Production Ready
// ============================================================================

param location string = resourceGroup().location
param environment string = 'prod'
param projectName string = 'acmecompany'
param appServicePlanSku string = 'P1V2'
param sqlAdminUsername string = 'sqladmin'
@secure()
param sqlAdminPassword string
param enableMonitoring bool = true
param enableBackup bool = true

var uniqueSuffix = uniqueString(resourceGroup().id)
var vnetName = 'vnet-${projectName}-${environment}'
var appServicePlanName = 'asp-${projectName}-${environment}'
var appServiceName = 'app-${projectName}-${environment}-${uniqueSuffix}'
var sqlServerName = 'sql-${projectName}-${environment}-${uniqueSuffix}'
var sqlDatabaseName = 'db-${projectName}'
var keyVaultName = 'kv-${projectName}-${uniqueSuffix}'
var appInsightsName = 'appi-${projectName}-${environment}'
var storageAccountName = 'st${projectName}${environment}${uniqueSuffix}'
var nsgName = 'nsg-${projectName}-${environment}'
var logAnalyticsWorkspaceName = 'law-${projectName}-${environment}-${uniqueSuffix}'

// ============================================================================
// 1. LOG ANALYTICS WORKSPACE
// ============================================================================
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
  }
}

// ============================================================================
// 2. APPLICATION INSIGHTS
// ============================================================================
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    RetentionInDays: 90
    WorkspaceResourceId: logAnalyticsWorkspace.id
  }
}

// ============================================================================
// 3. KEY VAULT
// ============================================================================
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableSoftDelete: true
    enablePurgeProtection: true
    enableRbacAuthorization: true
  }
}

// ============================================================================
// 4. NETWORK SECURITY GROUP - (dependsOn)
// ============================================================================
resource nsg 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowHTTP'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
    ]
  }
}

// ============================================================================
// 5. VIRTUAL NETWORK - (dependsOn)
// ============================================================================
resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: { addressPrefixes: ['10.0.0.0/16'] }
    subnets: [
      {
        name: 'subnet-app'
        properties: {
          addressPrefix: '10.0.1.0/24'
          networkSecurityGroup: { id: nsg.id }
        }
      }
    ]
  }
}

// ============================================================================
// 6. SQL SERVER & DATABASE
// ============================================================================
resource sqlServer 'Microsoft.Sql/servers@2021-11-01' = {
  name: sqlServerName
  location: location
  properties: {
    administratorLogin: sqlAdminUsername
    administratorLoginPassword: sqlAdminPassword
  }
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2021-11-01' = {
  parent: sqlServer
  name: sqlDatabaseName
  location: location
  sku: { name: 'S2', tier: 'Standard' }
}

// ============================================================================
// 7. APP SERVICE PLAN
// ============================================================================
resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: appServicePlanName
  location: location
  kind: 'Linux'
  sku: { name: appServicePlanSku, tier: 'PremiumV2' }
  properties: { reserved: true }
}

// ============================================================================
// 8. APP SERVICE - (dependsOn)
// ============================================================================
resource appService 'Microsoft.Web/sites@2023-01-01' = {
  name: appServiceName
  location: location
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'DOTNET|6.0'
      appSettings: [
        { name: 'APPINSIGHTS_INSTRUMENTATIONKEY', value: appInsights.properties.InstrumentationKey }
      ]
      connectionStrings: [
        {
          name: 'DefaultConnection'
          connectionString: 'Server=tcp:${sqlServer.properties.fullyQualifiedDomainName},1433;Database=${sqlDatabase.name};User ID=${sqlAdminUsername};Password=${sqlAdminPassword};Encrypt=True;'
          type: 'SQLServer'
        }
      ]
    }
    virtualNetworkSubnetId: '${vnet.id}/subnets/subnet-app'
  }
}

// ============================================================================
// 9. OUTPUTS
// ============================================================================
output appServiceUrl string = 'https://${appService.properties.defaultHostName}'
output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName
output keyVaultUri string = keyVault.properties.vaultUri
