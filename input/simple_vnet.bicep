resource myVnet 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: 'myVnet'
  location: 'eastus'
  properties: {
    addressSpace: {
      addressPrefixes: ['10.0.0.0/16']
    }
  }
}

resource subnetA 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' = {
  name: 'subnetA'
  parent: myVnet
  properties: {
    addressPrefix: '10.0.1.0/24'
  }
}