
param location string = resourceGroup().location
// Ce template déploie une infrastructure simple avec un VNet, un compte de stockage et une VM.
// Le VNet est créé en premier, suivi du compte de stockage, puis de la VM qui dépend du compte de stockage.
// La VM dépend implicitement du VNet et du Storage, mais nous spécifions explicitement la dépendance du Storage pour garantir l'ordre de déploiement.
//c'est possible qu'on puisse déclarer les paramètres  ou des variables pour les noms des ressources, les SKU, etc., pour rendre le template plus flexible et réutilisable.

resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: 'main-vnet'
  location: location
  properties: {
    addressSpace: { addressPrefixes: ['10.0.0.0/16'] }
  }
}

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: 'store${uniqueString(resourceGroup().id)}'
  location: location
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
}

resource vm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: 'web-vm'
  location: location
  properties: {
    // La VM dépend implicitement du VNet et du Storage
    networkProfile: {
      networkInterfaces: [{ id: vnet.id }]
    }
  }
  dependsOn: [ storage ]
}
