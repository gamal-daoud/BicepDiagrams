// ============================================
// INFRASTRUCTURE DEVOPS / CI-CD
// Container Registry + AKS + Key Vault + ACR
// ============================================

param location string = resourceGroup().location
param devopsName string = 'cicd-platform'

// Log Analytics pour monitoring DevOps
resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: '${devopsName}-logs'
  location: location
  properties: { sku: { name: 'PerGB2018' } }
}

// Application Insights
resource devopsInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${devopsName}-insights'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logWorkspace.id
  }
}

// Key Vault pour secrets CI/CD
resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: '${devopsName}-kv-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    sku: { family: 'A', name: 'standard' }
    tenantId: subscription().tenantId
    enableSoftDelete: true
    enabledForDeployment: true
    enabledForTemplateDeployment: true
  }
}

// Container Registry
resource acr 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  name: '${replace(devopsName, '-', '')}${uniqueString(resourceGroup().id)}'
  location: location
  sku: { name: 'Premium' }
  properties: {
    adminUserEnabled: false
    policies: {
      retentionPolicy: { days: 30, status: 'enabled' }
      exportPolicy: { status: 'enabled' }
    }
  }
}

// Storage Account pour artefacts de build
resource buildStorage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: '${replace(devopsName, '-', '')}art${uniqueString(resourceGroup().id)}'
  location: location
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
}

// Blob Service
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: buildStorage
  name: 'default'
}

// Conteneur pour les artefacts
resource artifactsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'artifacts'
  properties: { publicAccess: 'None' }
}

// Conteneur pour les rapports de tests
resource reportsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'test-reports'
  properties: { publicAccess: 'None' }
}

// VNet pour AKS
resource aksVnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: '${devopsName}-vnet'
  location: location
  properties: {
    addressSpace: { addressPrefixes: ['10.6.0.0/16'] }
    subnets: [
      { name: 'aks-system-subnet', properties: { addressPrefix: '10.6.1.0/24' } }
      { name: 'aks-user-subnet', properties: { addressPrefix: '10.6.2.0/24' } }
    ]
  }
}

// NSG pour AKS
resource aksNsg 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: '${devopsName}-nsg'
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

// AKS Cluster de Production
resource prodAks 'Microsoft.ContainerService/managedClusters@2023-05-01' = {
  name: '${devopsName}-prod-aks'
  location: location
  identity: { type: 'SystemAssigned' }
  properties: {
    dnsPrefix: '${devopsName}-prod'
    kubernetesVersion: '1.27.3'
    agentPoolProfiles: [
      {
        name: 'systempool'
        count: 2
        vmSize: 'Standard_DS2_v2'
        mode: 'System'
        osType: 'Linux'
        vnetSubnetID: '${aksVnet.id}/subnets/aks-system-subnet'
      }
      {
        name: 'userpool'
        count: 3
        vmSize: 'Standard_DS3_v2'
        mode: 'User'
        osType: 'Linux'
        vnetSubnetID: '${aksVnet.id}/subnets/aks-user-subnet'
        enableAutoScaling: true
        minCount: 1
        maxCount: 10
      }
    ]
    addonProfiles: {
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: logWorkspace.id
        }
      }
    }
  }
  dependsOn: [acr, keyVault, artifactsContainer]
}

// AKS Cluster de Staging
resource stagingAks 'Microsoft.ContainerService/managedClusters@2023-05-01' = {
  name: '${devopsName}-staging-aks'
  location: location
  identity: { type: 'SystemAssigned' }
  properties: {
    dnsPrefix: '${devopsName}-staging'
    kubernetesVersion: '1.27.3'
    agentPoolProfiles: [{
      name: 'systempool'
      count: 2
      vmSize: 'Standard_DS2_v2'
      mode: 'System'
      osType: 'Linux'
      vnetSubnetID: '${aksVnet.id}/subnets/aks-system-subnet'
    }]
  }
  dependsOn: [prodAks]
}

// Flux GitOps pour le cluster Prod
resource prodFluxConfig 'Microsoft.KubernetesConfiguration/fluxConfigurations@2023-05-01' = {
  name: 'prod-gitops'
  scope: prodAks
  properties: {
    scope: 'cluster'
    namespace: 'flux-system'
    sourceKind: 'GitRepository'
    gitRepository: {
      url: 'https://github.com/myorg/k8s-manifests'
      repositoryRef: { branch: 'main' }
    }
    kustomizations: {
      production: {
        path: './production'
        syncIntervalInSeconds: 120
      }
    }
  }
}

// Redis pour cache pipeline
resource buildCache 'Microsoft.Cache/redis@2023-04-01' = {
  name: '${devopsName}-cache-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    sku: { name: 'Standard', family: 'C', capacity: 1 }
  }
  dependsOn: [prodFluxConfig]
}

output acrLoginServer string = acr.properties.loginServer
output prodAksName string = prodAks.name
output stagingAksName string = stagingAks.name
