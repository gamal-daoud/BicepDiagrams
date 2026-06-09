@description('Optional. The location to deploy to.')
param location string = resourceGroup().location

@description('Required. The name of the Virtual Network to create.')
param virtualNetworkName string

@description('Required. The address prefix for the Virtual Network.')
param addressPrefix string = '10.1.0.0/16'

param mainSubnetAddressPrefix string = cidrSubnet(addressPrefix, 24, 1)

@description('Optional. The network security rules to use in the network security group associated with the main subnet.')
param networkSecurityRules array = []

@description('Tags to apply on the resources.')
param tags object = {}

@description('Name of the Network Security Group')
param networkSecurityGroupName string = 'nsg-subnet-main'

// Définition du Network Security Group (ressource directement, pas un module)
resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: networkSecurityGroupName
  location: location
  properties: {
    securityRules: networkSecurityRules
  }
  tags: tags
}

// Définition du Virtual Network (ressource directement, pas un module)
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [
      {
        name: 'mainSubnet'
        properties: {
          addressPrefix: mainSubnetAddressPrefix
          networkSecurityGroup: {
            id: networkSecurityGroup.id
          }
          defaultOutboundAccess: false
        }
      }
    ]
  }
  tags: tags
}

@description('The name of the virtual network.')
output vnetName string = virtualNetwork.name

@description('The resource ID of the virtual network.')
output vnetResourceId string = virtualNetwork.id

@description('The resource ID of the main subnet.')
output mainSubnetResourceId string = virtualNetwork.properties.subnets[0].id
