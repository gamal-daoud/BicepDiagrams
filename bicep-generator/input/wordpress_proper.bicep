resource VpcId 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: 'VpcId'
  location: 'eastus'
  properties: {
    addressSpace: {
      addressPrefixes: ['10.0.0.0/16']
    }
  }
}

resource VpcIdWebSecurityGroup 'Microsoft.Network/networkSecurityGroups@2021-01-01' = {
  name: 'VpcIdWebSecurityGroup'
  location: 'eastus'
}

resource VpcIdDBSecurityGroup 'Microsoft.Network/networkSecurityGroups@2021-01-01' = {
  name: 'VpcIdDBSecurityGroup'
  location: 'eastus'
}

resource VpcIdWebSecurityGroupWordPressInstance 'Microsoft.Compute/virtualMachines@2021-01-01' = {
  name: 'VpcIdWebSecurityGroupWordPressInstance'
  
  location: 'eastus'
  properties: {
    
    
  }
}

resource VpcIdDBSecurityGroupWordPressDB 'Microsoft.DBforMySQL/flexibleServers@2021-01-01' = {
  name: 'VpcIdDBSecurityGroupWordPressDB'
  
  location: 'eastus'
  properties: {
    
    
  }
}