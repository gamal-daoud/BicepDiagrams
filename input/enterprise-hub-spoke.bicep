// ============================================
// ARCHITECTURE HUB-AND-SPOKE ENTERPRISE
// Hub VNet + Spoke VNets + VPN Gateway + Firewall
// ============================================

param location string = resourceGroup().location
param hubName string = 'enterprise-hub'

// ===== HUB VNET =====
resource hubVnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: '${hubName}-vnet'
  location: location
  properties: {
    addressSpace: { addressPrefixes: ['10.0.0.0/8'] }
    subnets: [
      { name: 'GatewaySubnet', properties: { addressPrefix: '10.0.0.0/27' } }
      { name: 'AzureFirewallSubnet', properties: { addressPrefix: '10.0.1.0/26' } }
      { name: 'AzureBastionSubnet', properties: { addressPrefix: '10.0.2.0/27' } }
      { name: 'management-subnet', properties: { addressPrefix: '10.0.3.0/24' } }
    ]
  }
}

// NSG Hub
resource hubNsg 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: '${hubName}-nsg'
  location: location
  properties: {
    securityRules: [{
      name: 'DenyAllInbound'
      properties: {
        priority: 4096
        protocol: '*'
        access: 'Deny'
        direction: 'Inbound'
        sourceAddressPrefix: '*'
        sourcePortRange: '*'
        destinationAddressPrefix: '*'
        destinationPortRange: '*'
      }
    }]
  }
}

// Public IP pour VPN Gateway
resource vpnGatewayPip 'Microsoft.Network/publicIPAddresses@2023-04-01' = {
  name: '${hubName}-vpn-pip'
  location: location
  sku: { name: 'Standard' }
  properties: { publicIPAllocationMethod: 'Static' }
}

// Public IP pour Bastion
resource bastionPip 'Microsoft.Network/publicIPAddresses@2023-04-01' = {
  name: '${hubName}-bastion-pip'
  location: location
  sku: { name: 'Standard' }
  properties: { publicIPAllocationMethod: 'Static' }
}

// Bastion Host pour accès sécurisé
resource bastionHost 'Microsoft.Network/bastionHosts@2023-04-01' = {
  name: '${hubName}-bastion'
  location: location
  properties: {
    ipConfigurations: [{
      name: 'bastionConfig'
      properties: {
        publicIPAddress: { id: bastionPip.id }
        subnet: {
          id: '${hubVnet.id}/subnets/AzureBastionSubnet'
        }
      }
    }]
  }
  dependsOn: [hubVnet]
}

// ===== SPOKE 1 - Production =====
resource prodSpoke 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: 'prod-spoke-vnet'
  location: location
  properties: {
    addressSpace: { addressPrefixes: ['10.1.0.0/16'] }
    subnets: [
      { name: 'app-subnet', properties: { addressPrefix: '10.1.1.0/24' } }
      { name: 'db-subnet', properties: { addressPrefix: '10.1.2.0/24' } }
    ]
  }
}

// Peering Hub → Prod Spoke
resource hubToProdPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-04-01' = {
  parent: hubVnet
  name: 'hub-to-prod'
  properties: {
    remoteVirtualNetwork: { id: prodSpoke.id }
    allowForwardedTraffic: true
    allowGatewayTransit: true
  }
}

// ===== SPOKE 2 - Development =====
resource devSpoke 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: 'dev-spoke-vnet'
  location: location
  properties: {
    addressSpace: { addressPrefixes: ['10.2.0.0/16'] }
    subnets: [
      { name: 'dev-subnet', properties: { addressPrefix: '10.2.1.0/24' } }
      { name: 'test-subnet', properties: { addressPrefix: '10.2.2.0/24' } }
    ]
  }
}

// Peering Hub → Dev Spoke
resource hubToDevPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-04-01' = {
  parent: hubVnet
  name: 'hub-to-dev'
  properties: {
    remoteVirtualNetwork: { id: devSpoke.id }
    allowForwardedTraffic: true
    allowGatewayTransit: true
  }
}

// Log Analytics Workspace Hub
resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: '${hubName}-logs'
  location: location
  properties: { sku: { name: 'PerGB2018' } }
}

// VM de gestion dans le Hub
resource mgmtVm 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: '${hubName}-mgmt-vm'
  location: location
  properties: {
    hardwareProfile: { vmSize: 'Standard_B2s' }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter'
        version: 'latest'
      }
      osDisk: { createOption: 'FromImage', managedDisk: { storageAccountType: 'Standard_LRS' } }
    }
    osProfile: {
      computerName: 'mgmt-vm'
      adminUsername: 'azureadmin'
      adminPassword: 'P@ssw0rd123!'
    }
    networkProfile: {
      networkInterfaces: [{ id: mgmtNic.id }]
    }
  }
  dependsOn: [bastionHost]
}

// NIC pour la VM de gestion
resource mgmtNic 'Microsoft.Network/networkInterfaces@2023-04-01' = {
  name: '${hubName}-mgmt-nic'
  location: location
  properties: {
    ipConfigurations: [{
      name: 'ipconfig1'
      properties: {
        subnet: { id: '${hubVnet.id}/subnets/management-subnet' }
        privateIPAllocationMethod: 'Dynamic'
      }
    }]
  }
  dependsOn: [hubVnet, hubNsg]
}

output hubVnetId string = hubVnet.id
output prodSpokeId string = prodSpoke.id
output devSpokeId string = devSpoke.id
output bastionHostId string = bastionHost.id
