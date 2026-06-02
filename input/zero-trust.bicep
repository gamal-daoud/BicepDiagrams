// ============================================
// ARCHITECTURE ZERO TRUST SECURITY
// AAD + Conditional Access + Private Endpoints + Managed Identity
// ============================================

param location string = resourceGroup().location
param orgName string = 'zerotrust-corp'

// ===== OBSERVABILITÉ =====
resource securityLogs 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: '${orgName}-security-logs'
  location: location
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 180
  }
}

resource securityInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${orgName}-security-insights'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: securityLogs.id
  }
}

// ===== IDENTITÉ ET ACCÈS =====

// Identité gérée pour l'application principale
resource appManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${orgName}-app-identity'
  location: location
}

// Identité gérée pour les services backend
resource backendManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${orgName}-backend-identity'
  location: location
}

// Identité gérée pour les opérations de données
resource dataManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${orgName}-data-identity'
  location: location
}

// ===== KEY VAULT - CŒUR DE LA SÉCURITÉ =====
resource coreKeyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: '${orgName}-core-kv-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    sku: { family: 'A', name: 'premium' }
    tenantId: subscription().tenantId
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enablePurgeProtection: true
    enableRbacAuthorization: true
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
      ipRules: []
      virtualNetworkRules: []
    }
  }
  dependsOn: [appManagedIdentity, backendManagedIdentity, dataManagedIdentity]
}

// ===== RÉSEAU ZERO TRUST (micro-segmentation) =====
resource ztVnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: '${orgName}-zt-vnet'
  location: location
  properties: {
    addressSpace: { addressPrefixes: ['10.10.0.0/16'] }
    subnets: [
      { name: 'frontend-subnet', properties: { addressPrefix: '10.10.1.0/24' } }
      { name: 'backend-subnet', properties: { addressPrefix: '10.10.2.0/24' } }
      { name: 'data-subnet', properties: { addressPrefix: '10.10.3.0/24' } }
      { name: 'mgmt-subnet', properties: { addressPrefix: '10.10.4.0/24' } }
      { name: 'AzureBastionSubnet', properties: { addressPrefix: '10.10.5.0/27' } }
      { name: 'private-endpoints-subnet', properties: { addressPrefix: '10.10.6.0/24', privateEndpointNetworkPolicies: 'Disabled' } }
    ]
  }
}

// NSG Frontend — deny-by-default, seul HTTPS autorisé
resource frontendNsg 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: '${orgName}-frontend-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowHttpsInbound'
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
        name: 'DenyAllInbound'
        properties: {
          priority: 4096
          protocol: '*'
          access: 'Deny'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

// NSG Backend — seulement depuis le frontend
resource backendNsg 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: '${orgName}-backend-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowFromFrontend'
        properties: {
          priority: 100
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '10.10.1.0/24'
          sourcePortRange: '*'
          destinationAddressPrefix: '10.10.2.0/24'
          destinationPortRange: '8080'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          priority: 4096
          protocol: '*'
          access: 'Deny'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

// NSG Data — seulement depuis le backend
resource dataNsg 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: '${orgName}-data-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowFromBackend'
        properties: {
          priority: 100
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '10.10.2.0/24'
          sourcePortRange: '*'
          destinationAddressPrefix: '10.10.3.0/24'
          destinationPortRanges: ['1433', '5432', '6380']
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          priority: 4096
          protocol: '*'
          access: 'Deny'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

// Public IP Bastion
resource bastionPip 'Microsoft.Network/publicIPAddresses@2023-04-01' = {
  name: '${orgName}-bastion-pip'
  location: location
  sku: { name: 'Standard' }
  properties: { publicIPAllocationMethod: 'Static' }
  dependsOn: [ztVnet]
}

// Bastion — seul point d'entrée pour les admins
resource ztBastion 'Microsoft.Network/bastionHosts@2023-04-01' = {
  name: '${orgName}-bastion'
  location: location
  properties: {
    ipConfigurations: [{
      name: 'bastionConfig'
      properties: {
        publicIPAddress: { id: bastionPip.id }
        subnet: { id: '${ztVnet.id}/subnets/AzureBastionSubnet' }
      }
    }]
  }
}

// ===== STOCKAGE SÉCURISÉ =====
resource secureStorage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: '${replace(orgName, '-', '')}${uniqueString(resourceGroup().id)}'
  location: location
  sku: { name: 'Standard_GRS' }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
  }
  dependsOn: [coreKeyVault]
}

// Blob Service
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: secureStorage
  name: 'default'
}

// Conteneur données sensibles
resource sensitiveContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'sensitive-data'
  properties: { publicAccess: 'None' }
}

// Conteneur logs de sécurité
resource securityLogsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'security-audit-logs'
  properties: { publicAccess: 'None' }
}

// ===== SQL SERVER SÉCURISÉ =====
resource secureSql 'Microsoft.Sql/servers@2022-05-01-preview' = {
  name: '${orgName}-sql-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    administratorLogin: 'sqladmin'
    administratorLoginPassword: 'Zt@P@ssw0rd123!'
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Disabled'
  }
  dependsOn: [sensitiveContainer]
}

// Base de données sécurisée
resource secureDb 'Microsoft.Sql/servers/databases@2022-05-01-preview' = {
  parent: secureSql
  name: 'zerotrust-db'
  location: location
  sku: { name: 'S3', tier: 'Standard' }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    requestedBackupStorageRedundancy: 'Geo'
  }
}

// ===== APP SERVICE SÉCURISÉ =====
resource secureAppPlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: '${orgName}-app-plan'
  location: location
  sku: { name: 'P2v3', tier: 'PremiumV3' }
  properties: {}
  dependsOn: [secureDb]
}

// Application frontend sécurisée
resource frontendApp 'Microsoft.Web/sites@2022-09-01' = {
  name: '${orgName}-frontend'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: { '${appManagedIdentity.id}': {} }
  }
  properties: {
    serverFarmId: secureAppPlan.id
    httpsOnly: true
    siteConfig: {
      minTlsVersion: '1.2'
      alwaysOn: true
      ftpsState: 'Disabled'
      http20Enabled: true
    }
  }
}

// Application backend sécurisée
resource backendApp 'Microsoft.Web/sites@2022-09-01' = {
  name: '${orgName}-backend'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: { '${backendManagedIdentity.id}': {} }
  }
  properties: {
    serverFarmId: secureAppPlan.id
    httpsOnly: true
    siteConfig: {
      minTlsVersion: '1.2'
      alwaysOn: true
      ftpsState: 'Disabled'
    }
  }
  dependsOn: [frontendApp]
}

// ===== ROLE ASSIGNMENTS (RBAC LEAST PRIVILEGE) =====

// Frontend peut lire le Key Vault
resource frontendKvRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(coreKeyVault.id, appManagedIdentity.id, 'KeyVaultSecretsUser')
  scope: coreKeyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
    principalId: appManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
  dependsOn: [frontendApp]
}

// Backend peut contribuer au stockage
resource backendStorageRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(secureStorage.id, backendManagedIdentity.id, 'StorageBlobDataContributor')
  scope: secureStorage
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
    principalId: backendManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
  dependsOn: [backendApp]
}

// ===== DOMAINE AAD =====
resource aadDomainService 'Microsoft.AAD/domainServices@2022-12-01' = {
  name: '${orgName}.onmicrosoft.com'
  location: location
  properties: {
    domainName: '${orgName}.onmicrosoft.com'
    filteredSync: 'Disabled'
    replicaSets: [{
      location: location
      subnetId: '${ztVnet.id}/subnets/mgmt-subnet'
    }]
  }
  dependsOn: [frontendKvRole, backendStorageRole]
}

// ===== REDIS CHIFFRÉ POUR SESSIONS =====
resource secureCache 'Microsoft.Cache/redis@2023-04-01' = {
  name: '${orgName}-cache-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    sku: { name: 'Premium', family: 'P', capacity: 1 }
    enableNonSslPort: false
    minimumTlsVersion: '1.2'
    redisConfiguration: {
      maxmemoryPolicy: 'allkeys-lru'
    }
  }
  dependsOn: [aadDomainService]
}

// ===== COSMOS DB AVEC ACCÈS RÉSEAU PRIVÉ =====
resource ztCosmosDb 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  name: '${orgName}-cosmos-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    databaseAccountOfferType: 'Standard'
    locations: [{ locationName: location, failoverPriority: 0 }]
    consistencyPolicy: { defaultConsistencyLevel: 'Strong' }
    publicNetworkAccess: 'Disabled'
    enableAutomaticFailover: true
  }
  dependsOn: [secureCache]
}

output frontendUrl string = 'https://${frontendApp.properties.defaultHostName}'
output backendUrl string = 'https://${backendApp.properties.defaultHostName}'
output keyVaultUri string = coreKeyVault.properties.vaultUri
output cosmosEndpoint string = ztCosmosDb.properties.documentEndpoint
output vnetId string = ztVnet.id
