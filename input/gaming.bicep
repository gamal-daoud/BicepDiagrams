// ============================================
// INFRASTRUCTURE GAMING EN LIGNE
// AKS Game Servers + CosmosDB + Redis + CDN
// ============================================

param location string = resourceGroup().location
param gameName string = 'cloudgame'

// Log Analytics pour métriques jeu
resource gameLogs 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: '${gameName}-logs'
  location: location
  properties: { sku: { name: 'PerGB2018' } }
}

// Application Insights pour performance en jeu
resource gameInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${gameName}-insights'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: gameLogs.id
  }
}

// Container Registry pour images des serveurs de jeu
resource gameRegistry 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  name: '${gameName}registry${uniqueString(resourceGroup().id)}'
  location: location
  sku: { name: 'Premium' }
  properties: { adminUserEnabled: false }
}

// Storage Account pour saves et assets
resource gameStorage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: '${gameName}stor${uniqueString(resourceGroup().id)}'
  location: location
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: { accessTier: 'Hot' }
}

// Blob Service
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: gameStorage
  name: 'default'
}

// Conteneur sauvegardes joueurs
resource savesContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'player-saves'
  properties: { publicAccess: 'None' }
}

// Conteneur assets du jeu (textures, sons)
resource assetsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'game-assets'
  properties: { publicAccess: 'Blob' }
}

// Conteneur replays
resource replaysContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'game-replays'
  properties: { publicAccess: 'None' }
}

// VNet pour l'infrastructure de jeu
resource gameVnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: '${gameName}-vnet'
  location: location
  properties: {
    addressSpace: { addressPrefixes: ['10.8.0.0/16'] }
    subnets: [
      { name: 'gameserver-subnet', properties: { addressPrefix: '10.8.1.0/24' } }
      { name: 'matchmaking-subnet', properties: { addressPrefix: '10.8.2.0/24' } }
      { name: 'api-subnet', properties: { addressPrefix: '10.8.3.0/24' } }
    ]
  }
}

// NSG pour serveurs de jeu
resource gameNsg 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: '${gameName}-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowGamePorts'
        properties: {
          priority: 100
          protocol: 'Udp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRanges: ['7777-7800', '9000-9010']
        }
      }
      {
        name: 'AllowWebhooks'
        properties: {
          priority: 110
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
    ]
  }
}

// Public IP pour le Load Balancer des serveurs de jeu
resource gameLbPip 'Microsoft.Network/publicIPAddresses@2023-04-01' = {
  name: '${gameName}-lb-pip'
  location: location
  sku: { name: 'Standard' }
  properties: { publicIPAllocationMethod: 'Static' }
}

// Load Balancer pour répartir les connexions de jeu
resource gameLb 'Microsoft.Network/loadBalancers@2023-04-01' = {
  name: '${gameName}-lb'
  location: location
  sku: { name: 'Standard' }
  properties: {
    frontendIPConfigurations: [{
      name: 'gameServerFrontend'
      properties: { publicIPAddress: { id: gameLbPip.id } }
    }]
    backendAddressPools: [{ name: 'gameServerPool' }]
    loadBalancingRules: [{
      name: 'gameTrafficRule'
      properties: {
        frontendIPConfiguration: { id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', '${gameName}-lb', 'gameServerFrontend') }
        backendAddressPool: { id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', '${gameName}-lb', 'gameServerPool') }
        protocol: 'Udp'
        frontendPort: 7777
        backendPort: 7777
        probe: { id: resourceId('Microsoft.Network/loadBalancers/probes', '${gameName}-lb', 'gameHealthProbe') }
      }
    }]
    probes: [{
      name: 'gameHealthProbe'
      properties: { protocol: 'Tcp', port: 7777, intervalInSeconds: 5, numberOfProbes: 2 }
    }]
  }
  dependsOn: [gameVnet]
}

// Pool de serveurs de jeu (VMSS)
resource gameServerVmss 'Microsoft.Compute/virtualMachineScaleSets@2023-03-01' = {
  name: '${gameName}-gameserver-vmss'
  location: location
  sku: { name: 'Standard_F4s_v2', tier: 'Standard', capacity: 3 }
  properties: {
    upgradePolicy: { mode: 'Rolling' }
    virtualMachineProfile: {
      storageProfile: {
        imageReference: {
          publisher: 'Canonical'
          offer: 'UbuntuServer'
          sku: '20_04-lts'
          version: 'latest'
        }
        osDisk: { createOption: 'FromImage', managedDisk: { storageAccountType: 'Premium_LRS' } }
      }
      osProfile: {
        computerNamePrefix: 'gamesvr'
        adminUsername: 'gameadmin'
        adminPassword: 'G@me@P@ssw0rd!'
      }
      networkProfile: {
        networkInterfaceConfigurations: [{
          name: 'game-nic'
          properties: {
            primary: true
            ipConfigurations: [{
              name: 'ipconfig1'
              properties: {
                subnet: { id: '${gameVnet.id}/subnets/gameserver-subnet' }
                loadBalancerBackendAddressPools: [{ id: '${gameLb.id}/backendAddressPools/gameServerPool' }]
              }
            }]
          }
        }]
      }
    }
  }
}

// AKS pour les services de matchmaking et API
resource gameAks 'Microsoft.ContainerService/managedClusters@2023-05-01' = {
  name: '${gameName}-services-aks'
  location: location
  identity: { type: 'SystemAssigned' }
  properties: {
    dnsPrefix: '${gameName}-svc'
    kubernetesVersion: '1.27.3'
    agentPoolProfiles: [{
      name: 'systempool'
      count: 3
      vmSize: 'Standard_DS3_v2'
      mode: 'System'
      osType: 'Linux'
      vnetSubnetID: '${gameVnet.id}/subnets/matchmaking-subnet'
      enableAutoScaling: true
      minCount: 2
      maxCount: 20
    }]
    addonProfiles: {
      omsagent: {
        enabled: true
        config: { logAnalyticsWorkspaceResourceID: gameLogs.id }
      }
    }
  }
  dependsOn: [gameServerVmss, gameRegistry]
}

// CosmosDB pour profils joueurs et scores
resource gameCosmosDb 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  name: '${gameName}-cosmos-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    databaseAccountOfferType: 'Standard'
    locations: [{ locationName: location, failoverPriority: 0 }]
    consistencyPolicy: { defaultConsistencyLevel: 'Eventual' }
  }
  dependsOn: [gameAks]
}

// Redis Cache pour classements et sessions en temps réel
resource leaderboardCache 'Microsoft.Cache/redis@2023-04-01' = {
  name: '${gameName}-leaderboard-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    sku: { name: 'Premium', family: 'P', capacity: 2 }
    enableNonSslPort: false
    redisConfiguration: { maxmemoryPolicy: 'allkeys-lru' }
  }
  dependsOn: [gameCosmosDb]
}

// Key Vault pour secrets de jeu
resource gameKeyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: '${gameName}-kv-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    sku: { family: 'A', name: 'standard' }
    tenantId: subscription().tenantId
    enableSoftDelete: true
  }
  dependsOn: [leaderboardCache]
}

output gameServerLbIp string = gameLbPip.properties.ipAddress
output aksClusterName string = gameAks.name
output cosmosEndpoint string = gameCosmosDb.properties.documentEndpoint
output registryServer string = gameRegistry.properties.loginServer
