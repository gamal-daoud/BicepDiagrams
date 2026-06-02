// ============================================
// ARCHITECTURE MICROSERVICES
// Container Apps + Registry + Monitoring
// ============================================

param location string = resourceGroup().location
param environmentName string = 'microservices-env'

// Container Registry
resource registry 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  name: 'msvcregistry${uniqueString(resourceGroup().id)}'
  location: location
  sku: { name: 'Standard' }
  properties: { adminUserEnabled: true }
}

// Log Analytics pour monitoring
resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: 'msvc-logs'
  location: location
  properties: { sku: { name: 'PerGB2018' } }
}

// Application Insights
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'msvc-insights'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logWorkspace.id
  }
}

// Managed Environment pour Container Apps
resource managedEnv 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: environmentName
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logWorkspace.properties.customerId
        sharedKey: logWorkspace.listKeys().primarySharedKey
      }
    }
  }
}

// Service API Gateway
resource apiGateway 'Microsoft.App/containerApps@2023-05-01' = {
  name: 'api-gateway'
  location: location
  properties: {
    managedEnvironmentId: managedEnv.id
    configuration: {
      ingress: { external: true, targetPort: 8080 }
    }
    template: {
      containers: [{
        name: 'api-gateway'
        image: '${registry.name}.azurecr.io/api-gateway:latest'
        resources: { cpu: json('0.5'), memory: '1Gi' }
      }]
      scale: { minReplicas: 1, maxReplicas: 10 }
    }
  }
}

// Service Utilisateurs
resource userService 'Microsoft.App/containerApps@2023-05-01' = {
  name: 'user-service'
  location: location
  properties: {
    managedEnvironmentId: managedEnv.id
    configuration: {
      ingress: { external: false, targetPort: 3000 }
    }
    template: {
      containers: [{
        name: 'user-service'
        image: '${registry.name}.azurecr.io/user-service:latest'
        resources: { cpu: json('0.25'), memory: '512Mi' }
      }]
      scale: { minReplicas: 1, maxReplicas: 5 }
    }
  }
  dependsOn: [apiGateway]
}

// Service Commandes
resource orderService 'Microsoft.App/containerApps@2023-05-01' = {
  name: 'order-service'
  location: location
  properties: {
    managedEnvironmentId: managedEnv.id
    configuration: {
      ingress: { external: false, targetPort: 3001 }
    }
    template: {
      containers: [{
        name: 'order-service'
        image: '${registry.name}.azurecr.io/order-service:latest'
        resources: { cpu: json('0.25'), memory: '512Mi' }
      }]
      scale: { minReplicas: 1, maxReplicas: 5 }
    }
  }
  dependsOn: [apiGateway]
}

// Service Catalogue Produits
resource catalogService 'Microsoft.App/containerApps@2023-05-01' = {
  name: 'catalog-service'
  location: location
  properties: {
    managedEnvironmentId: managedEnv.id
    configuration: {
      ingress: { external: false, targetPort: 3002 }
    }
    template: {
      containers: [{
        name: 'catalog-service'
        image: '${registry.name}.azurecr.io/catalog-service:latest'
        resources: { cpu: json('0.25'), memory: '512Mi' }
      }]
      scale: { minReplicas: 1, maxReplicas: 8 }
    }
  }
  dependsOn: [apiGateway]
}

// Base de données CosmosDB
resource cosmosDb 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  name: 'msvc-cosmos-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    databaseAccountOfferType: 'Standard'
    locations: [{ locationName: location, failoverPriority: 0 }]
    consistencyPolicy: { defaultConsistencyLevel: 'Session' }
  }
}

// Redis Cache
resource redisCache 'Microsoft.Cache/redis@2023-04-01' = {
  name: 'msvc-redis-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    sku: { name: 'Standard', family: 'C', capacity: 1 }
  }
  dependsOn: [userService, orderService, catalogService]
}

output gatewayUrl string = 'https://${apiGateway.properties.configuration.ingress.fqdn}'
output registryLoginServer string = registry.properties.loginServer
