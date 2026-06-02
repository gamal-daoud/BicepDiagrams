// ============================================
// SAUVEGARDE ET RÉCUPÉRATION APRÈS SINISTRE
// Recovery Services Vault + SQL Geo-Redundant + Storage GRS
// ============================================

param location string = resourceGroup().location
param drLocation string = 'northeurope'
param projectName string = 'backup-dr'

// ===== LOG ANALYTICS =====
resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: '${projectName}-logs'
  location: location
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 90
  }
}

// Application Insights
resource drInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${projectName}-insights'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logWorkspace.id
  }
}

// ===== KEY VAULT =====
resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: '${projectName}-kv-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    sku: { family: 'A', name: 'premium' }
    tenantId: subscription().tenantId
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enablePurgeProtection: true
  }
}

// ===== STOCKAGE PRIMAIRE (GRS) =====
resource primaryStorage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: '${replace(projectName, '-', '')}prim${uniqueString(resourceGroup().id)}'
  location: location
  sku: { name: 'Standard_GRS' }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
  }
}

// Blob Service Primaire
resource primaryBlob 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: primaryStorage
  name: 'default'
}

// Conteneur backups application
resource appBackupContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: primaryBlob
  name: 'app-backups'
  properties: { publicAccess: 'None' }
}

// Conteneur backups base de données
resource dbBackupContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: primaryBlob
  name: 'db-backups'
  properties: { publicAccess: 'None' }
}

// Conteneur archives long terme
resource archiveContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: primaryBlob
  name: 'long-term-archive'
  properties: { publicAccess: 'None' }
}

// ===== STOCKAGE SECONDAIRE (DRSITE) =====
resource drStorage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: '${replace(projectName, '-', '')}dr${uniqueString(resourceGroup().id)}'
  location: drLocation
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
  }
  dependsOn: [appBackupContainer, dbBackupContainer, archiveContainer]
}

// Blob Service DR
resource drBlob 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: drStorage
  name: 'default'
}

// Conteneur DR
resource drContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: drBlob
  name: 'dr-failover'
  properties: { publicAccess: 'None' }
}

// ===== VNet PRIMAIRE =====
resource primaryVnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: '${projectName}-primary-vnet'
  location: location
  properties: {
    addressSpace: { addressPrefixes: ['10.9.0.0/16'] }
    subnets: [
      { name: 'app-subnet', properties: { addressPrefix: '10.9.1.0/24' } }
      { name: 'db-subnet', properties: { addressPrefix: '10.9.2.0/24' } }
      { name: 'AzureBastionSubnet', properties: { addressPrefix: '10.9.3.0/27' } }
    ]
  }
}

// NSG Primaire
resource primaryNsg 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: '${projectName}-primary-nsg'
  location: location
  properties: {
    securityRules: [{
      name: 'AllowHttpsInbound'
      properties: {
        priority: 100
        protocol: 'Tcp'
        access: 'Allow'
        direction: 'Inbound'
        sourceAddressPrefix: 'Internet'
        sourcePortRange: '*'
        destinationAddressPrefix: '*'
        destinationPortRange: '443'
      }
    }]
  }
}

// Public IP Bastion Primaire
resource bastionPip 'Microsoft.Network/publicIPAddresses@2023-04-01' = {
  name: '${projectName}-bastion-pip'
  location: location
  sku: { name: 'Standard' }
  properties: { publicIPAllocationMethod: 'Static' }
}

// Bastion pour accès sécurisé
resource bastion 'Microsoft.Network/bastionHosts@2023-04-01' = {
  name: '${projectName}-bastion'
  location: location
  properties: {
    ipConfigurations: [{
      name: 'bastionConfig'
      properties: {
        publicIPAddress: { id: bastionPip.id }
        subnet: { id: '${primaryVnet.id}/subnets/AzureBastionSubnet' }
      }
    }]
  }
  dependsOn: [primaryVnet]
}

// ===== SQL SERVER PRIMAIRE =====
resource primarySql 'Microsoft.Sql/servers@2022-05-01-preview' = {
  name: '${projectName}-primary-sql-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    administratorLogin: 'sqladmin'
    administratorLoginPassword: 'P@ssw0rd123!'
    minimalTlsVersion: '1.2'
  }
  dependsOn: [drContainer]
}

// Base de données principale avec backup LTR
resource primaryDb 'Microsoft.Sql/servers/databases@2022-05-01-preview' = {
  parent: primarySql
  name: 'production-db'
  location: location
  sku: { name: 'P1', tier: 'Premium' }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    requestedBackupStorageRedundancy: 'Geo'
  }
}

// Règle Firewall SQL
resource sqlFirewall 'Microsoft.Sql/servers/firewallRules@2022-05-01-preview' = {
  parent: primarySql
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// ===== SQL SERVER SECONDAIRE (DR) =====
resource drSql 'Microsoft.Sql/servers@2022-05-01-preview' = {
  name: '${projectName}-dr-sql-${uniqueString(resourceGroup().id)}'
  location: drLocation
  properties: {
    administratorLogin: 'sqladmin'
    administratorLoginPassword: 'P@ssw0rd123!'
    minimalTlsVersion: '1.2'
  }
  dependsOn: [primaryDb]
}

// Base de données DR (géo-réplica)
resource drDb 'Microsoft.Sql/servers/databases@2022-05-01-preview' = {
  parent: drSql
  name: 'production-db-replica'
  location: drLocation
  sku: { name: 'P1', tier: 'Premium' }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    createMode: 'Secondary'
    sourceDatabaseId: primaryDb.id
  }
}

// ===== APP SERVICE (PRIMAIRE) =====
resource appPlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: '${projectName}-app-plan'
  location: location
  sku: { name: 'P2v3', tier: 'PremiumV3' }
  properties: {}
  dependsOn: [primaryDb]
}

// Application principale
resource mainApp 'Microsoft.Web/sites@2022-09-01' = {
  name: '${projectName}-app-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    serverFarmId: appPlan.id
    httpsOnly: true
    siteConfig: {
      minTlsVersion: '1.2'
      alwaysOn: true
    }
  }
  dependsOn: [drDb]
}

// Identité gérée pour l'app
resource appIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${projectName}-app-identity'
  location: location
  dependsOn: [mainApp]
}

// Role Assignment pour l'accès au stockage
resource storageRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(primaryStorage.id, appIdentity.id, 'StorageBlobDataContributor')
  scope: primaryStorage
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
    principalId: appIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
  dependsOn: [appIdentity]
}

// Redis Cache pour sessions applicatives
resource sessionCache 'Microsoft.Cache/redis@2023-04-01' = {
  name: '${projectName}-cache-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    sku: { name: 'Standard', family: 'C', capacity: 1 }
    enableNonSslPort: false
  }
  dependsOn: [storageRoleAssignment]
}

output primaryAppUrl string = 'https://${mainApp.properties.defaultHostName}'
output primarySqlFqdn string = primarySql.properties.fullyQualifiedDomainName
output drSqlFqdn string = drSql.properties.fullyQualifiedDomainName
output primaryStorageEndpoint string = primaryStorage.properties.primaryEndpoints.blob
output drStorageEndpoint string = drStorage.properties.primaryEndpoints.blob
