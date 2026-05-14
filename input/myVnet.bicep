resource myVnet 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: 'myVnet'
  location: ' bat M5'
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

resource subnetB 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' = {
  name: 'subnetB'
  parent: myVnet
  properties: {
    addressPrefix: '10.0.1.1/24'
  }
}
resource subnetC 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' = {
  name: 'subnetC'
  parent: myVnet
  properties: {
    addressPrefix: '10.0.1.2/24'
  }
}
