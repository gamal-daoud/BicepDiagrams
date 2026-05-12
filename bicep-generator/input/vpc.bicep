
module web './web.bicep' = {
  name: 'WebSecurityGroup'
}

module db './db.bicep' = {
  name: 'DBSecurityGroup'
}

resource vpcNode 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: 'VpcId'
  location: 'eastus'
}
