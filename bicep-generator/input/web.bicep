
resource wordpressVm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: 'WordPressInstance'
  location: 'eastus'
  properties: {
    hardwareProfile: { vmSize: 'Standard_DS1_v2' }
  }
}

resource webNsgNode 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: 'WebSecurityGroup'
  location: 'eastus'
}
