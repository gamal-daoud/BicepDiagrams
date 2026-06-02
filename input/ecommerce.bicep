// ============================================
// INFRASTRUCTURE E-COMMERCE
// ============================================

// Paramètres
param location string = resourceGroup().location
param environment string = 'production'

// Correction 1 : Ajouter @secure() pour le mot de passe SQL
@secure()
param sqlAdminPassword string

// Variables
var suffix = uniqueString(resourceGroup().id)
var commonTags = {
  Environment: environment
  Application: 'Ecommerce'
  CostCenter: 'Marketing'
}

// ============================================
// RESSOURCE 1 : APPLICATION GATEWAY (WAF)
// ============================================
resource appGateway 'Microsoft.Network/applicationGateways@2023-05-01' = {
  name: 'agw-ecommerce-${suffix}'
  location: location
  tags: commonTags
  properties: {
    sku: {
      name: 'WAF_v2'
      tier: 'WAF_v2'
      capacity: 2
    }
    webApplicationFirewallConfiguration: {
      enabled: true
      firewallMode: 'Prevention'
      ruleSetType: 'OWASP'
      ruleSetVersion: '3.2'
    }
  }
}

// ============================================
// RESSOURCE 2 : APP SERVICE PLAN
// ============================================
resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: 'asp-ecommerce-${environment}'
  location: location
  tags: commonTags
  sku: {
    name: 'P1v2'
    capacity: 2
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

// ============================================
// RESSOURCE 3 : WEB APP (frontend e-commerce)
// ============================================
resource webApp 'Microsoft.Web/sites@2023-01-01' = {
  name: 'web-ecommerce-${suffix}'
  location: location
  tags: commonTags
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'NODE|18-lts'
      alwaysOn: true
      appSettings: [
        {
          name: 'REDIS_CONNECTION_STRING'
          value: '${redisCache.name}.redis.cache.windows.net:6380,password=${redisCache.listKeys().primaryKey}'
        }
      ]
    }
  }
}

// ============================================
// RESSOURCE 4 : SQL DATABASE
// ============================================
resource sqlServer 'Microsoft.Sql/servers@2023-05-01-preview' = {
  name: 'sql-ecommerce-${suffix}'
  location: location
  tags: commonTags
  properties: {
    administratorLogin: 'sqladmin'
    administratorLoginPassword: sqlAdminPassword
    version: '12.0'
  }
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-05-01-preview' = {
  parent: sqlServer
  name: 'ecommerce-db'
  location: location
  tags: commonTags
  sku: {
    name: 'S2'
    tier: 'Standard'
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 268435456000
  }
}

// ============================================
// RESSOURCE 5 : REDIS CACHE (session store)
// ============================================
resource redisCache 'Microsoft.Cache/redis@2023-08-01' = {
  name: 'redis-ecommerce-${suffix}'
  location: location
  tags: commonTags
  properties: {
    sku: {
      name: 'Standard'
      family: 'C'
      capacity: 1
    }
    enableNonSslPort: false
    minimumTlsVersion: '1.2'
    redisConfiguration: {
      'maxmemory-policy': 'allkeys-lru'
    }
  }
}

// ============================================
// RESSOURCE 6 : STORAGE ACCOUNT (produits images)
// ============================================
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'stecommerce${suffix}'
  location: location
  tags: commonTags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: true
  }
}

// Correction 2 : Créer d'abord le blobService
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
}

// Puis le container avec blobService comme parent
resource productsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'product-images'
  properties: {
    publicAccess: 'Blob'
  }
}

// ============================================
// RESSOURCE 7 : KEY VAULT (secrets)
// ============================================
resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: 'kv-ecommerce-${suffix}'
  location: location
  tags: commonTags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
  }
}

resource sqlSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: keyVault
  name: 'SqlConnectionString'
  properties: {
    value: 'Server=tcp:${sqlServer.properties.fullyQualifiedDomainName},1433;Initial Catalog=ecommerce-db;Persist Security Info=False;User ID=sqladmin;Password=${sqlAdminPassword};Encrypt=True;'
  }
}
