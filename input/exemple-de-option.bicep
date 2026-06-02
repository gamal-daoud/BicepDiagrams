// ============================================
// AZURE vs DIAGRAM - EXEMPLE DE NOMS DIFFÉRENTS
// ============================================

param location string = resourceGroup().location
var suffix = uniqueString(resourceGroup().id)

// ============================================
// 1. AKS (Azure Kubernetes Service)
// Le même service Azure peut avoir 2 noms de classes différentes !
// ============================================

resource monAKS 'Microsoft.ContainerService/managedClusters@2023-02-01' = {
  name: 'monaks${suffix}'
  location: location
  tags: {
    service: 'AKS'
    description: 'Azure Kubernetes Service'
    // Ce service peut être représenté par :
    // - diagrams.azure.compute.AKS
    // - diagrams.azure.containers.KubernetesServices
  }
  properties: {
    dnsPrefix: 'monaks'
    agentPoolProfiles: [
      {
        name: 'agentpool'
        count: 3
        vmSize: 'Standard_DS2_v2'
      }
    ]
  }
}

// ============================================
// 2. Container Registry
// ============================================

resource monRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: 'monregistry${suffix}'
  location: location
  tags: {
    service: 'ContainerRegistry'
    // Possibilités :
    // - diagrams.azure.containers.ContainerRegistry
    // - diagrams.azure.containers.Registries
  }
  sku: { name: 'Basic' }
  properties: { adminUserEnabled: true }
}

// ============================================
// 3. Redis Cache
// ============================================

resource monRedis 'Microsoft.Cache/redis@2023-08-01' = {
  name: 'monredis${suffix}'
  location: location
  tags: {
    service: 'RedisCache'
    // Possibilités :
    // - diagrams.azure.database.CacheForRedis
    // - diagrams.azure.database.RedisCache
  }
  properties: {
    sku: { name: 'Standard', family: 'C', capacity: 1 }
  }
}

// ============================================
// 4. Storage Account
// ============================================

resource monStorage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'monstorage${suffix}'
  location: location
  tags: {
    service: 'StorageAccount'
    // Possibilités :
    // - diagrams.azure.storage.StorageAccounts
    // - diagrams.azure.storage.BlobStorage
  }
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
}

// ============================================
// 5. Virtual Network
// ============================================

resource monVnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: 'monvnet${suffix}'
  location: location
  tags: {
    service: 'VirtualNetwork'
    // Possibilités :
    // - diagrams.azure.networking.VirtualNetworks
    // - diagrams.azure.networking.VNet
  }
  properties: {
    addressSpace: { addressPrefixes: ['10.0.0.0/16'] }
  }
}

// OUTPUTS


output message string = 'Regarde la différence entre Azure (service) et Diagrams (noms de classes)'
