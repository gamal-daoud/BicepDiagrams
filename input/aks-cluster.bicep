param location string = resourceGroup().location

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: 'aksVnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/8'
      ]
    }
    subnets: [
      {
        name: 'aksSubnet'
        properties: {
          addressPrefix: '10.240.0.0/16'
        }
      }
    ]
  }
}

resource aks 'Microsoft.ContainerService/managedClusters@2023-08-01' = {
  name: 'aksCluster'
  location: location
  properties: {
    dnsPrefix: 'akscluster-dns'
    agentPoolProfiles: [
      {
        name: 'agentpool'
        count: 3
        vmSize: 'Standard_DS2_v2'
        osType: 'Linux'
        mode: 'System'
        vnetSubnetID: vnet.properties.subnets[0].id
      }
    ]
  }
}
