// ============================================
// WORDPRESS INFRASTRUCTURE SUR AZURE
// Version CORRIGÉE avec dépendances explicites
// ============================================

param location string = 'eastus'

// 1. VPC (Virtual Network)
resource vpc 'Microsoft.Network/virtualNetworks@2023-02-01' = {
  name: 'VpcId'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: ['10.0.0.0/16']
    }
    subnets: [
      {
        name: 'web-subnet'
        properties: { addressPrefix: '10.0.1.0/24' }
      }
      {
        name: 'db-subnet'
        properties: { addressPrefix: '10.0.2.0/24' }
      }
    ]
  }
}

// 2. Web Security Group
resource webSecurityGroup 'Microsoft.Network/networkSecurityGroups@2023-02-01' = {
  name: 'WebSecurityGroup'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowHTTP'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          access: 'Allow'
          direction: 'Inbound'
          priority: 100
        }
      }
    ]
  }
}

// 3. DB Security Group
resource dbSecurityGroup 'Microsoft.Network/networkSecurityGroups@2023-02-01' = {
  name: 'DBSecurityGroup'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowMySQL'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3306'
          access: 'Allow'
          direction: 'Inbound'
          priority: 100
        }
      }
    ]
  }
}

// 4. WordPress Database
resource wordpressDB 'Microsoft.DBforMySQL/flexibleServers@2022-12-01' = {
  name: 'WordPressDB'
  location: location
  sku: { name: 'B_Standard_B1s' }
  properties: {
    administratorLogin: 'wpadmin'
    administratorLoginPassword: 'Password123!'
    version: '8.0'
    network: {
      delegatedSubnetResourceId: resourceId('Microsoft.Network/virtualNetworks/subnets', 'VpcId', 'db-subnet')
    }
  }

  // Firewall rule pour permettre l'accès depuis la VM
  resource firewallRule 'firewallRules@2022-12-01' = {
    name: 'AllowFromWeb'
    properties: {
      startIpAddress: '10.0.1.0'
      endIpAddress: '10.0.1.255'
    }
  }
}

// 5. Network Interface pour la VM
resource nic 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: 'wordpress-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', 'VpcId', 'web-subnet')
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
    networkSecurityGroup: { id: webSecurityGroup.id }
  }
}

// 6. WordPress Instance (VM)
resource wordpressInstance 'Microsoft.Compute/virtualMachines@2023-09-01' = {
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
      osDisk: { createOption: 'FromImage' }
    }
    osProfile: {
      computerName: 'wordpress'
      adminUsername: 'wpadmin'
      adminPassword: 'Password123!'
    }
    networkProfile: {
      networkInterfaces: [{ id: nic.id }]
    }
  }
  dependsOn: [wordpressDB]
}

// 7. Outputs
output vnetId string = vpc.id
output vmId string = wordpressInstance.id
output dbId string = wordpressDB.id
