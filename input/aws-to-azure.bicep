// Infrastructure Bicep équivalente au code Terraform AWS Cognito
param location string = resourceGroup().location

// App Service avec authentification (équivalent Cognito + API Gateway)
resource appService 'Microsoft.Web/sites@2022-03-01' = {
  name: 'diagramai-api${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    authSettings: {
      enabled: true
      unauthenticatedClientAction: 'RedirectToLoginPage'
      defaultProvider: 'AzureActiveDirectory'
      clientId: 'your-app-client-id'
      issuer: 'https://login.microsoftonline.com/${subscription().tenantId}/v2.0'
    }
  }
}

resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: 'diagramai-plan'
  location: location
  sku: { name: 'B1', tier: 'Basic' }
}

// Routes API
// GET /health - public
// POST /generate - protégé par JWT

output appServiceUrl string = 'https://${appService.name}.azurewebsites.net'
output issuerUrl string = 'https://login.microsoftonline.com/${subscription().tenantId}/v2.0'
