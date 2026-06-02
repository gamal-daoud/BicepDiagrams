// ============================================
// ARCHITECTURE MACHINE LEARNING
// Azure ML Workspace + Compute Clusters + Storage
// ============================================

param location string = resourceGroup().location
param mlProjectName string = 'ml-platform'

// Log Analytics
resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: '${mlProjectName}-logs'
  location: location
  properties: { sku: { name: 'PerGB2018' } }
}

// Application Insights pour ML
resource mlInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${mlProjectName}-insights'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logWorkspace.id
  }
}

// Key Vault pour ML
resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: '${mlProjectName}-kv-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    sku: { family: 'A', name: 'standard' }
    tenantId: subscription().tenantId
    enableSoftDelete: true
  }
}

// Storage Account pour les datasets ML
resource mlStorage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: '${replace(mlProjectName, '-', '')}${uniqueString(resourceGroup().id)}'
  location: location
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: {
    isHnsEnabled: true
    accessTier: 'Hot'
  }
}

// Blob Service
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: mlStorage
  name: 'default'
}

// Conteneur datasets d'entrainement
resource trainingContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'training-data'
  properties: { publicAccess: 'None' }
}

// Conteneur modèles entraînés
resource modelsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'trained-models'
  properties: { publicAccess: 'None' }
}

// Conteneur résultats d'expériences
resource experimentsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'experiments'
  properties: { publicAccess: 'None' }
}

// VNet pour ML Workspace
resource mlVnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: '${mlProjectName}-vnet'
  location: location
  properties: {
    addressSpace: { addressPrefixes: ['10.5.0.0/16'] }
    subnets: [
      { name: 'training-subnet', properties: { addressPrefix: '10.5.1.0/24' } }
      { name: 'inference-subnet', properties: { addressPrefix: '10.5.2.0/24' } }
    ]
  }
}

// NSG pour les clusters ML
resource mlNsg 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: '${mlProjectName}-nsg'
  location: location
  properties: {
    securityRules: [{
      name: 'AllowAzureML'
      properties: {
        priority: 100
        protocol: 'Tcp'
        access: 'Allow'
        direction: 'Inbound'
        sourceAddressPrefix: 'AzureMachineLearning'
        sourcePortRange: '*'
        destinationAddressPrefix: '*'
        destinationPortRange: '44224'
      }
    }]
  }
}

// VM pour calcul (compute instance)
resource mlComputeVm 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: '${mlProjectName}-compute'
  location: location
  properties: {
    hardwareProfile: { vmSize: 'Standard_DS3_v2' }
    storageProfile: {
      imageReference: {
        publisher: 'microsoft-dsvm'
        offer: 'dsvm-win-2019'
        sku: 'server-2019'
        version: 'latest'
      }
      osDisk: { createOption: 'FromImage', managedDisk: { storageAccountType: 'Premium_LRS' } }
    }
    osProfile: {
      computerName: 'mlcompute'
      adminUsername: 'azureadmin'
      adminPassword: 'P@ssw0rd123!'
    }
    networkProfile: {
      networkInterfaces: [{ id: mlNic.id }]
    }
  }
  dependsOn: [trainingContainer, modelsContainer]
}

// NIC pour la VM ML
resource mlNic 'Microsoft.Network/networkInterfaces@2023-04-01' = {
  name: '${mlProjectName}-nic'
  location: location
  properties: {
    ipConfigurations: [{
      name: 'ipconfig1'
      properties: {
        subnet: { id: '${mlVnet.id}/subnets/training-subnet' }
        privateIPAllocationMethod: 'Dynamic'
      }
    }]
  }
  dependsOn: [mlVnet, mlNsg]
}

// VMSS pour l'inférence en parallèle
resource inferenceVmss 'Microsoft.Compute/virtualMachineScaleSets@2023-03-01' = {
  name: '${mlProjectName}-inference-vmss'
  location: location
  sku: { name: 'Standard_DS2_v2', tier: 'Standard', capacity: 2 }
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
        computerNamePrefix: 'inference'
        adminUsername: 'azureadmin'
        adminPassword: 'P@ssw0rd123!'
      }
      networkProfile: {
        networkInterfaceConfigurations: [{
          name: 'inference-nic'
          properties: {
            primary: true
            ipConfigurations: [{
              name: 'ipconfig1'
              properties: {
                subnet: { id: '${mlVnet.id}/subnets/inference-subnet' }
              }
            }]
          }
        }]
      }
    }
  }
  dependsOn: [mlComputeVm]
}

// Redis Cache pour caching des prédictions
resource predictionCache 'Microsoft.Cache/redis@2023-04-01' = {
  name: '${mlProjectName}-cache-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    sku: { name: 'Standard', family: 'C', capacity: 1 }
  }
  dependsOn: [inferenceVmss]
}

output storageEndpoint string = mlStorage.properties.primaryEndpoints.dfs
output computeVmId string = mlComputeVm.id
