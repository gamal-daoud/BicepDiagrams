// ============================================
// ARCHITECTURE SANTÉ (HEALTHCARE)
// FHIR API + SQL + Storage sécurisé + Key Vault
// ============================================

param location string = resourceGroup().location
param healthcareOrg string = 'clinique-azure'

// Log Analytics pour conformité HIPAA
resource complianceLogs 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: '${healthcareOrg}-compliance-logs'
  location: location
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 365
  }
}

// Application Insights pour monitoring médical
resource healthInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${healthcareOrg}-insights'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: complianceLogs.id
  }
}

// Key Vault avec protection renforcée pour données médicales
resource medicalKeyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: '${healthcareOrg}-kv-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    sku: { family: 'A', name: 'premium' }
    tenantId: subscription().tenantId
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enablePurgeProtection: true
    enabledForDiskEncryption: true
  }
}

// VNet sécurisé pour données médicales
resource healthVnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: '${healthcareOrg}-vnet'
  location: location
  properties: {
    addressSpace: { addressPrefixes: ['10.7.0.0/16'] }
    subnets: [
      { name: 'fhir-subnet', properties: { addressPrefix: '10.7.1.0/24' } }
      { name: 'db-subnet', properties: { addressPrefix: '10.7.2.0/24' } }
      { name: 'app-subnet', properties: { addressPrefix: '10.7.3.0/24' } }
    ]
  }
}

// NSG strict pour données médicales
resource healthNsg 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: '${healthcareOrg}-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowHttpsOnly'
        properties: {
          priority: 100
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRange: '443'
        }
      }
      {
        name: 'DenyAllOtherInbound'
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
      }
    ]
  }
}

// Storage Account chiffré pour dossiers médicaux
resource medicalStorage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: '${replace(healthcareOrg, '-', '')}${uniqueString(resourceGroup().id)}'
  location: location
  sku: { name: 'Standard_GRS' }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    encryption: {
      services: {
        blob: { enabled: true }
        file: { enabled: true }
      }
      keySource: 'Microsoft.Storage'
    }
  }
}

// Blob Service
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: medicalStorage
  name: 'default'
}

// Conteneur Dossiers Patients (chiffré)
resource patientsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'patient-records'
  properties: { publicAccess: 'None' }
}

// Conteneur Imagerie Médicale (DICOM)
resource dicomContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'medical-imaging'
  properties: { publicAccess: 'None' }
}

// Conteneur Résultats Labo
resource labContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'lab-results'
  properties: { publicAccess: 'None' }
}

// SQL Server pour dossiers médicaux structurés
resource medicalSqlServer 'Microsoft.Sql/servers@2022-05-01-preview' = {
  name: '${healthcareOrg}-sql-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    administratorLogin: 'healthadmin'
    administratorLoginPassword: 'H3alth@P@ss123!'
    minimalTlsVersion: '1.2'
  }
  dependsOn: [patientsContainer, dicomContainer]
}

// Base de données patients
resource patientsDb 'Microsoft.Sql/servers/databases@2022-05-01-preview' = {
  parent: medicalSqlServer
  name: 'patients-db'
  location: location
  sku: { name: 'S4', tier: 'Standard' }
  properties: { collation: 'SQL_Latin1_General_CP1_CI_AS' }
}

// Base de données ordonnances
resource prescriptionsDb 'Microsoft.Sql/servers/databases@2022-05-01-preview' = {
  parent: medicalSqlServer
  name: 'prescriptions-db'
  location: location
  sku: { name: 'S2', tier: 'Standard' }
  properties: { collation: 'SQL_Latin1_General_CP1_CI_AS' }
  dependsOn: [patientsDb]
}

// App Service Plan pour l'application médicale
resource healthAppPlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: '${healthcareOrg}-plan'
  location: location
  sku: { name: 'P2v3', tier: 'PremiumV3' }
  properties: {}
}

// Application Web médicale
resource healthApp 'Microsoft.Web/sites@2022-09-01' = {
  name: '${healthcareOrg}-portal'
  location: location
  properties: {
    serverFarmId: healthAppPlan.id
    httpsOnly: true
    siteConfig: {
      minTlsVersion: '1.2'
      alwaysOn: true
      ftpsState: 'Disabled'
    }
  }
  dependsOn: [prescriptionsDb]
}

// Identité gérée pour l'application
resource healthAppIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${healthcareOrg}-identity'
  location: location
  dependsOn: [healthApp]
}

// CosmosDB pour les données FHIR
resource fhirCosmos 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  name: '${healthcareOrg}-fhir-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    databaseAccountOfferType: 'Standard'
    locations: [{ locationName: location, failoverPriority: 0 }]
    consistencyPolicy: { defaultConsistencyLevel: 'Strong' }
    enableAutomaticFailover: false
  }
  dependsOn: [healthAppIdentity]
}

// Redis Cache pour sessions médicales
resource sessionCache 'Microsoft.Cache/redis@2023-04-01' = {
  name: '${healthcareOrg}-cache-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    sku: { name: 'Premium', family: 'P', capacity: 1 }
    enableNonSslPort: false
    minimumTlsVersion: '1.2'
  }
  dependsOn: [fhirCosmos]
}

output healthPortalUrl string = 'https://${healthApp.properties.defaultHostName}'
output fhirEndpoint string = fhirCosmos.properties.documentEndpoint
output medicalStorageEndpoint string = medicalStorage.properties.primaryEndpoints.blob
