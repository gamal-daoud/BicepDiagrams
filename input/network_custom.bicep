param location string = 'university of lille'

resource switch 'Microsoft.Network/localNetworkGateways@2021-02-01' = {
  name: 'MainSwitch'
  location: location
  properties: {
    localNetworkAddressSpace: { addressPrefixes: [] }
    gatewayIpAddress: '1.1.1.1'
  }
}

resource pc1 'Microsoft.Compute/virtualMachines@2021-07-01' = {
  name: 'PC-1'
  location: location
  dependsOn: [switch]
}

resource pc2 'Microsoft.Compute/virtualMachines@2021-07-01' = {
  name: 'PC-2'
  location: location
  dependsOn: [switch]
}

resource pc3 'Microsoft.Compute/virtualMachines@2021-07-01' = {
  name: 'PC-3'
  location: location
  dependsOn: [switch]
}

resource pc4 'Microsoft.Compute/virtualMachines@2021-07-01' = {
  name: 'PC-4'
  location: location
  dependsOn: [switch]
}
