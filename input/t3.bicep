// ============================================================================
// INFRASTRUCTURE AZURE COMPLÈTE - ARCHITECTURE 3-TIERS
// ============================================================================
// Description: Application web e-commerce avec frontend, API et base de données
// Architecture: Hub-and-Spoke avec Azure App Service, Functions, SQL Database
// Sécurité: Key Vault, Private Endpoints, Application Gateway avec WAF
// Monitoring: Application Insights, Log Analytics, Alerts
// ============================================================================

// ============================================================================
// PARAMÈTRES
// ============================================================================

@description('Environnement de déploiement')
@allowed([
  'dev'
  'staging'
  'prod'
])
param environment string = 'dev'

@description('Région Azure principale')
param location string = resourceGroup().location

@description('Préfixe pour nommer toutes les ressources')
@minLength(3)
@maxLength(10)
param projectPrefix string = 'ecommerce'

@description('Nom du propriétaire du projet')
param ownerName string = 'Gamal Daoud'

@description('Adresse email pour les alertes')
param alertEmail string = 'admin@example.com'

@description('Mot de passe administrateur SQL')
@secure()
param sqlAdminPassword string

@description('CIDR du Virtual Network Hub')
param hubVnetAddressPrefix string = '10.0.0.0/16'

@description('CIDR du Virtual Network Spoke (Application)')
param spokeAppVnetAddressPrefix string = '10.1.0.0/16'

@description('CIDR du Virtual Network Spoke (Data)')
param spokeDataVnetAddressPrefix string = '10.2.0.0/16'

@description('Activer les Private Endpoints')
param enablePrivateEndpoints bool = true

@description('SKU de l\'App Service Plan')
@allowed([
  'B1'
  'B2'
  'B3'
  'S1'
  'S2'
  'S3'
  'P1v2'
  'P2v2'
  'P3v2'
])
param appServicePlanSku string = 'S1'

// ============================================================================
// VARIABLES
// ============================================================================

var uniqueSuffix = uniqueString(resourceGroup().id)

// commonTags défini correctement (sans utcNow)
var commonTags = {
  Environment: environment
  Project: projectPrefix
  Owner: ownerName
  ManagedBy: 'Bicep'
}

// Noms des ressources
var keyVaultName = '${projectPrefix}-kv-${uniqueSuffix}'
var logAnalyticsName = '${projectPrefix}-law-${environment}'
var appInsightsName = '${projectPrefix}-ai-${environment}'
var appServicePlanName = '${projectPrefix}-asp-${environment}'
var webAppName = '${projectPrefix}-web-${environment}-${uniqueSuffix}'
var functionAppName = '${projectPrefix}-func-${environment}-${uniqueSuffix}'
var sqlServerName = '${projectPrefix}-sql-${environment}-${uniqueSuffix}'
var sqlDatabaseName = '${projectPrefix}-sqldb-${environment}'
var storageAccountName = '${projectPrefix}st${environment}${take(uniqueSuffix, 6)}'
var cosmosDbAccountName = '${projectPrefix}-cosmos-${environment}-${uniqueSuffix}'
var redisCacheName = '${projectPrefix}-redis-${environment}-${uniqueSuffix}'
var containerRegistryName = '${projectPrefix}acr${environment}${take(uniqueSuffix, 6)}'
var appGatewayName = '${projectPrefix}-agw-${environment}'
var publicIpName = '${projectPrefix}-pip-agw-${environment}'
var nsgWebName = '${projectPrefix}-nsg-web-${environment}'
var nsgAppName = '${projectPrefix}-nsg-app-${environment}'
var nsgDataName = '${projectPrefix}-nsg-data-${environment}'

// Noms des réseaux
var hubVnetName = '${projectPrefix}-vnet-hub-${environment}'
var spokeAppVnetName = '${projectPrefix}-vnet-spoke-app-${environment}'
var spokeDataVnetName = '${projectPrefix}-vnet-spoke-data-${environment}'

// Sous-réseaux
var gatewaySubnetPrefix = '10.0.0.0/24'
var firewallSubnetPrefix = '10.0.1.0/24'
var bastionSubnetPrefix = '10.0.2.0/24'
var appGatewaySubnetPrefix = '10.1.0.0/24'
var webAppSubnetPrefix = '10.1.1.0/24'
var functionSubnetPrefix = '10.1.2.0/24'
var privateEndpointSubnetPrefix = '10.2.0.0/24'
var sqlSubnetPrefix = '10.2.1.0/24'

// ============================================================================
// RESSOURCES - NETWORKING (HUB)
// ============================================================================

// Network Security Group - Hub
resource nsgHub 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: '${projectPrefix}-nsg-hub-${environment}'
  location: location
  tags: commonTags
  properties: {
    securityRules: [
      {
        name: 'AllowHTTPS'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowHTTP'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
    ]
  }
}

// Virtual Network Hub
resource hubVnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: hubVnetName
  location: location
  tags: commonTags
  properties: {
    addressSpace: {
      addressPrefixes: [
        hubVnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: gatewaySubnetPrefix
        }
      }
      {
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: firewallSubnetPrefix
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: bastionSubnetPrefix
          networkSecurityGroup: {
            id: nsgHub.id
          }
        }
      }
    ]
  }
}

// ============================================================================
// RESSOURCES - NETWORKING (SPOKE APPLICATION)
// ============================================================================

// Network Security Group - Web Tier
resource nsgWeb 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: nsgWebName
  location: location
  tags: commonTags
  properties: {
    securityRules: [
      {
        name: 'AllowAppGateway'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: appGatewaySubnetPrefix
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 4096
          direction: 'Inbound'
        }
      }
    ]
  }
}

// Network Security Group - App Tier
resource nsgApp 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: nsgAppName
  location: location
  tags: commonTags
  properties: {
    securityRules: [
      {
        name: 'AllowWebTier'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: webAppSubnetPrefix
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
    ]
  }
}

// Virtual Network Spoke Application
resource spokeAppVnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: spokeAppVnetName
  location: location
  tags: commonTags
  properties: {
    addressSpace: {
      addressPrefixes: [
        spokeAppVnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: 'AppGatewaySubnet'
        properties: {
          addressPrefix: appGatewaySubnetPrefix
        }
      }
      {
        name: 'WebAppSubnet'
        properties: {
          addressPrefix: webAppSubnetPrefix
          networkSecurityGroup: {
            id: nsgWeb.id
          }
          delegations: [
            {
              name: 'delegation'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
        }
      }
      {
        name: 'FunctionSubnet'
        properties: {
          addressPrefix: functionSubnetPrefix
          networkSecurityGroup: {
            id: nsgApp.id
          }
          delegations: [
            {
              name: 'delegation'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
        }
      }
    ]
  }
}

// Peering Hub -> Spoke App
resource hubToSpokeAppPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-05-01' = {
  parent: hubVnet
  name: 'hub-to-spoke-app'
  properties: {
    remoteVirtualNetwork: {
      id: spokeAppVnet.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: true
    useRemoteGateways: false
  }
}

// Peering Spoke App -> Hub
resource spokeAppToHubPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-05-01' = {
  parent: spokeAppVnet
  name: 'spoke-app-to-hub'
  properties: {
    remoteVirtualNetwork: {
      id: hubVnet.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
  }
}

// ============================================================================
// RESSOURCES - NETWORKING (SPOKE DATA)
// ============================================================================

// Network Security Group - Data Tier
resource nsgData 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: nsgDataName
  location: location
  tags: commonTags
  properties: {
    securityRules: [
      {
        name: 'AllowAppTier'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '1433'
          sourceAddressPrefix: functionSubnetPrefix
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 4096
          direction: 'Inbound'
        }
      }
    ]
  }
}

// Virtual Network Spoke Data
resource spokeDataVnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: spokeDataVnetName
  location: location
  tags: commonTags
  properties: {
    addressSpace: {
      addressPrefixes: [
        spokeDataVnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: 'PrivateEndpointSubnet'
        properties: {
          addressPrefix: privateEndpointSubnetPrefix
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: 'SqlSubnet'
        properties: {
          addressPrefix: sqlSubnetPrefix
          networkSecurityGroup: {
            id: nsgData.id
          }
        }
      }
    ]
  }
}

// Peering Hub -> Spoke Data
resource hubToSpokeDataPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-05-01' = {
  parent: hubVnet
  name: 'hub-to-spoke-data'
  properties: {
    remoteVirtualNetwork: {
      id: spokeDataVnet.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: true
    useRemoteGateways: false
  }
}

// Peering Spoke Data -> Hub
resource spokeDataToHubPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-05-01' = {
  parent: spokeDataVnet
  name: 'spoke-data-to-hub'
  properties: {
    remoteVirtualNetwork: {
      id: hubVnet.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
  }
}

// ============================================================================
// RESSOURCES - APPLICATION GATEWAY & WAF
// ============================================================================

// Public IP pour Application Gateway
resource publicIp 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: publicIpName
  location: location
  tags: commonTags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: '${projectPrefix}-${environment}-${uniqueSuffix}'
    }
  }
}

// Application Gateway avec WAF
resource appGateway 'Microsoft.Network/applicationGateways@2023-05-01' = {
  name: appGatewayName
  location: location
  tags: commonTags
  properties: {
    sku: {
      name: 'WAF_v2'
      tier: 'WAF_v2'
      capacity: 2
    }
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {
          subnet: {
            id: '${spokeAppVnet.id}/subnets/AppGatewaySubnet'
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'appGatewayFrontendIP'
        properties: {
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'port_80'
        properties: {
          port: 80
        }
      }
      {
        name: 'port_443'
        properties: {
          port: 443
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'appServiceBackendPool'
        properties: {
          backendAddresses: [
            {
              fqdn: webApp.properties.defaultHostName
            }
          ]
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'appServiceBackendHttpSettings'
        properties: {
          port: 443
          protocol: 'Https'
          cookieBasedAffinity: 'Disabled'
          pickHostNameFromBackendAddress: true
          requestTimeout: 30
          probe: {
            id: resourceId('Microsoft.Network/applicationGateways/probes', appGatewayName, 'healthProbe')
          }
        }
      }
    ]
    httpListeners: [
      {
        name: 'httpListener'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appGatewayName, 'appGatewayFrontendIP')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGatewayName, 'port_80')
          }
          protocol: 'Http'
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'routingRule'
        properties: {
          ruleType: 'Basic'
          priority: 100
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appGatewayName, 'httpListener')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appGatewayName, 'appServiceBackendPool')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appGatewayName, 'appServiceBackendHttpSettings')
          }
        }
      }
    ]
    probes: [
      {
        name: 'healthProbe'
        properties: {
          protocol: 'Https'
          path: '/health'
          interval: 30
          timeout: 30
          unhealthyThreshold: 3
          pickHostNameFromBackendHttpSettings: true
        }
      }
    ]
    webApplicationFirewallConfiguration: {
      enabled: true
      firewallMode: 'Prevention'
      ruleSetType: 'OWASP'
      ruleSetVersion: '3.2'
      disabledRuleGroups: []
      requestBodyCheck: true
      maxRequestBodySizeInKb: 128
      fileUploadLimitInMb: 100
    }
  }
}

// ============================================================================
// RESSOURCES - MONITORING & LOGGING
// ============================================================================

// Log Analytics Workspace
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsName
  location: location
  tags: commonTags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

// Application Insights
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  tags: commonTags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// Action Group pour les alertes
resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: '${projectPrefix}-ag-${environment}'
  location: 'global'
  tags: commonTags
  properties: {
    groupShortName: 'EcomAlerts'
    enabled: true
    emailReceivers: [
      {
        name: 'EmailAdmin'
        emailAddress: alertEmail
        useCommonAlertSchema: true
      }
    ]
  }
}

// Alert - High CPU
resource cpuAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: '${projectPrefix}-alert-cpu-${environment}'
  location: 'global'
  tags: commonTags
  properties: {
    description: 'Alert when CPU exceeds 80%'
    severity: 2
    enabled: true
    scopes: [
      appServicePlan.id
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HighCPU'
          metricName: 'CpuPercentage'
          operator: 'GreaterThan'
          threshold: 80
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}

// ============================================================================
// RESSOURCES - SÉCURITÉ (KEY VAULT)
// ============================================================================

// Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: keyVaultName
  location: location
  tags: commonTags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enabledForDeployment: true
    enabledForDiskEncryption: true
    enabledForTemplateDeployment: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enablePurgeProtection: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: []
      virtualNetworkRules: enablePrivateEndpoints ? [] : [
        {
          id: '${spokeAppVnet.id}/subnets/WebAppSubnet'
        }
        {
          id: '${spokeAppVnet.id}/subnets/FunctionSubnet'
        }
      ]
    }
  }
}

// Secret - SQL Connection String
resource sqlConnectionStringSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: keyVault
  name: 'SqlConnectionString'
  properties: {
    value: 'Server=tcp:${sqlServer.properties.fullyQualifiedDomainName},1433;Initial Catalog=${sqlDatabaseName};Persist Security Info=False;User ID=sqladmin;Password=${sqlAdminPassword};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'
  }
}

// Secret - Storage Account Connection String
resource storageConnectionStringSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: keyVault
  name: 'StorageConnectionString'
  properties: {
    value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=core.windows.net'
  }
}

// ============================================================================
// RESSOURCES - STORAGE
// ============================================================================

// Storage Account
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  tags: commonTags
  sku: {
    name: 'Standard_GRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      virtualNetworkRules: [
        {
          id: '${spokeAppVnet.id}/subnets/FunctionSubnet'
          action: 'Allow'
        }
      ]
    }
    encryption: {
      services: {
        blob: {
          enabled: true
        }
        file: {
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
  }
}

// Blob Service
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: 7
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

// Container - Images
resource imagesContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'product-images'
  properties: {
    publicAccess: 'None'
  }
}

// Container - Backups
resource backupsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'backups'
  properties: {
    publicAccess: 'None'
  }
}

// ============================================================================
// RESSOURCES - BASE DE DONNÉES (SQL)
// ============================================================================

// SQL Server
resource sqlServer 'Microsoft.Sql/servers@2023-05-01-preview' = {
  name: sqlServerName
  location: location
  tags: commonTags
  properties: {
    administratorLogin: 'sqladmin'
    administratorLoginPassword: sqlAdminPassword
    version: '12.0'
    minimalTlsVersion: '1.2'
    publicNetworkAccess: enablePrivateEndpoints ? 'Disabled' : 'Enabled'
  }
}

// SQL Database
resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-05-01-preview' = {
  parent: sqlServer
  name: sqlDatabaseName
  location: location
  tags: commonTags
  sku: {
    name: 'S1'
    tier: 'Standard'
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 268435456000
    catalogCollation: 'SQL_Latin1_General_CP1_CI_AS'
    zoneRedundant: false
    readScale: 'Disabled'
    requestedBackupStorageRedundancy: 'Geo'
  }
}

// Firewall Rule - Allow Azure Services
resource sqlFirewallAzure 'Microsoft.Sql/servers/firewallRules@2023-05-01-preview' = if (!enablePrivateEndpoints) {
  parent: sqlServer
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// SQL Database Auditing
resource sqlAuditing 'Microsoft.Sql/servers/auditingSettings@2023-05-01-preview' = {
  parent: sqlServer
  name: 'default'
  properties: {
    state: 'Enabled'
    storageEndpoint: storageAccount.properties.primaryEndpoints.blob
    storageAccountAccessKey: storageAccount.listKeys().keys[0].value
    storageAccountSubscriptionId: subscription().subscriptionId
    retentionDays: 90
    isAzureMonitorTargetEnabled: true
  }
}

// ============================================================================
// RESSOURCES - BASE DE DONNÉES (COSMOS DB)
// ============================================================================

// Cosmos DB Account
resource cosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2023-11-15' = {
  name: cosmosDbAccountName
  location: location
  tags: commonTags
  kind: 'GlobalDocumentDB'
  properties: {
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    databaseAccountOfferType: 'Standard'
    enableAutomaticFailover: false
    enableMultipleWriteLocations: false
    capabilities: []
    publicNetworkAccess: 'Enabled'
  }
}

// Cosmos DB Database
resource cosmosDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2023-11-15' = {
  parent: cosmosDbAccount
  name: 'ecommerce-catalog'
  properties: {
    resource: {
      id: 'ecommerce-catalog'
    }
    options: {
      throughput: 400
    }
  }
}

// Cosmos DB Container
resource cosmosContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2023-11-15' = {
  parent: cosmosDatabase
  name: 'products'
  properties: {
    resource: {
      id: 'products'
      partitionKey: {
        paths: [
          '/categoryId'
        ]
        kind: 'Hash'
      }
      indexingPolicy: {
        indexingMode: 'consistent'
        includedPaths: [
          {
            path: '/*'
          }
        ]
        excludedPaths: [
          {
            path: '/_etag/?'
          }
        ]
      }
    }
  }
}

// ============================================================================
// RESSOURCES - CACHE (REDIS)
// ============================================================================

// Redis Cache
resource redisCache 'Microsoft.Cache/redis@2023-08-01' = {
  name: redisCacheName
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
    publicNetworkAccess: 'Enabled'
    redisConfiguration: {
      'maxmemory-policy': 'allkeys-lru'
    }
  }
}

// ============================================================================
// RESSOURCES - CONTAINER REGISTRY
// ============================================================================

// Azure Container Registry
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: containerRegistryName
  location: location
  tags: commonTags
  sku: {
    name: 'Standard'
  }
  properties: {
    adminUserEnabled: true
    publicNetworkAccess: 'Enabled'
    networkRuleBypassOptions: 'AzureServices'
    policies: {
      retentionPolicy: {
        status: 'enabled'
        days: 30
      }
    }
  }
}

// ============================================================================
// RESSOURCES - APP SERVICE (WEB APP)
// ============================================================================

// App Service Plan
resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: appServicePlanName
  location: location
  tags: commonTags
  sku: {
    name: appServicePlanSku
    capacity: 1
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

// Web App
resource webApp 'Microsoft.Web/sites@2023-01-01' = {
  name: webAppName
  location: location
  tags: commonTags
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    clientAffinityEnabled: false
    virtualNetworkSubnetId: '${spokeAppVnet.id}/subnets/WebAppSubnet'
    siteConfig: {
      linuxFxVersion: 'NODE|18-lts'
      alwaysOn: true
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      http20Enabled: true
      healthCheckPath: '/health'
      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '18-lts'
        }
        {
          name: 'API_ENDPOINT'
          value: 'https://${functionApp.properties.defaultHostName}/api'
        }
        {
          name: 'KEY_VAULT_URI'
          value: keyVault.properties.vaultUri
        }
      ]
    }
  }
}

// Web App Diagnostic Settings
resource webAppDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diagnostics'
  scope: webApp
  properties: {
    workspaceId: logAnalytics.id
    logs: [
      {
        category: 'AppServiceHTTPLogs'
        enabled: true
        retentionPolicy: {
          days: 30
          enabled: true
        }
      }
      {
        category: 'AppServiceConsoleLogs'
        enabled: true
        retentionPolicy: {
          days: 30
          enabled: true
        }
      }
      {
        category: 'AppServiceAppLogs'
        enabled: true
        retentionPolicy: {
          days: 30
          enabled: true
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          days: 30
          enabled: true
        }
      }
    ]
  }
}

// ============================================================================
// RESSOURCES - AZURE FUNCTIONS (API)
// ============================================================================

// Function App
resource functionApp 'Microsoft.Web/sites@2023-01-01' = {
  name: functionAppName
  location: location
  tags: commonTags
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    virtualNetworkSubnetId: '${spokeAppVnet.id}/subnets/FunctionSubnet'
    siteConfig: {
      linuxFxVersion: 'PYTHON|3.11'
      alwaysOn: true
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=core.windows.net'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=core.windows.net'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(functionAppName)
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'python'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'SQL_CONNECTION_STRING'
          value: '@Microsoft.KeyVault(SecretUri=${sqlConnectionStringSecret.properties.secretUri})'
        }
        {
          name: 'COSMOS_DB_ENDPOINT'
          value: cosmosDbAccount.properties.documentEndpoint
        }
        {
          name: 'COSMOS_DB_KEY'
          value: cosmosDbAccount.listKeys().primaryMasterKey
        }
        {
          name: 'REDIS_CONNECTION_STRING'
          value: '${redisCacheName}.redis.cache.windows.net:6380,password=${redisCache.listKeys().primaryKey},ssl=True,abortConnect=False'
        }
        {
          name: 'KEY_VAULT_URI'
          value: keyVault.properties.vaultUri
        }
      ]
    }
  }
}

// ============================================================================
// OUTPUTS
// ============================================================================

output webAppUrl string = 'https://${webApp.properties.defaultHostName}'
output functionAppUrl string = 'https://${functionApp.properties.defaultHostName}'
output appGatewayPublicIp string = publicIp.properties.ipAddress
output appGatewayFqdn string = publicIp.properties.dnsSettings.fqdn
output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName
output keyVaultUri string = keyVault.properties.vaultUri
output storageAccountName string = storageAccount.name
output cosmosDbEndpoint string = cosmosDbAccount.properties.documentEndpoint
output redisCacheName string = redisCache.name
output containerRegistryLoginServer string = containerRegistry.properties.loginServer
output logAnalyticsWorkspaceId string = logAnalytics.id
output appInsightsInstrumentationKey string = appInsights.properties.InstrumentationKey
