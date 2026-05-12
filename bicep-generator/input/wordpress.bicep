// WordPress Infrastructure on Azure
param location string = resourceGroup().location

// ========== RÉSEAU ==========
resource vpc 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: 'wordpress-vpc'
  location: location
  properties: {
    addressSpace: { addressPrefixes: ['10.0.0.0/16'] }
    subnets: [
      { name: 'web-subnet', properties: { addressPrefix: '10.0.1.0/24' } }
      { name: 'db-subnet', properties: { addressPrefix: '10.0.2.0/24' } }
    ]
  }
}

// ========== GROUPES DE SÉCURITÉ ==========
resource webSecurityGroup 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: 'WebSecurityGroup'
  location: location
  properties: {
    securityRules: [{
      name: 'AllowHTTP'
      properties: {
        protocol: 'Tcp'
        sourcePortRange: '*'
        destinationPortRange: '80'
        access: 'Allow'
        direction: 'Inbound'
        priority: 100
      }
    }]
  }
}

resource dbSecurityGroup 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: 'DBSecurityGroup'
  location: location
  properties: {
    securityRules: [{
      name: 'AllowMySQL'
      properties: {
        protocol: 'Tcp'
        sourcePortRange: '*'
        destinationPortRange: '3306'
        access: 'Allow'
        direction: 'Inbound'
        priority: 100
      }
    }]
  }
}

// ========== BASE DE DONNÉES ==========
resource wordpressDB 'Microsoft.DBforMySQL/flexibleServers@2022-12-01' = {
  name: 'wordpress-db'
  location: location
  properties: {
    administratorLogin: 'wpadmin'
    administratorLoginPassword: 'Password123!'
    version: '8.0'
  }
}

// ========== VM WORDPRESS ==========
resource wordpressVM 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: 'WordPressInstance'
  location: location
  properties: {
    hardwareProfile: { vmSize: 'Standard_B2s' }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'ubuntu-24_04-lts'
        sku: 'server'
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [{
        id: nic.id
        properties: { primary: true }
      }]
    }
  }
  dependsOn: [ wordpressDB ]
}

// Interface réseau pour la VM
resource nic 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: 'wordpress-nic'
  location: location
  properties: {
    ipConfigurations: [{
      name: 'ipconfig1'
      properties: {
        subnet: { id: vpc.properties.subnets[0].id }
        privateIPAllocationMethod: 'Dynamic'
      }
    }]
    networkSecurityGroup: { id: webSecurityGroup.id }
  }
}
