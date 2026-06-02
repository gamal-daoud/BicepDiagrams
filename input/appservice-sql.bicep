param location string = resourceGroup().location

resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: 'appServicePlan'
  location: location
  sku: {
    name: 'F1'
  }
}

resource webApp 'Microsoft.Web/sites@2023-01-01' = {
  name: 'webApp'
  location: location
  properties: {
    serverFarmId: appServicePlan.id
  }
}

resource sqlServer 'Microsoft.Sql/servers@2023-05-01-preview' = {
  name: 'sqlServer'
  location: location
  properties: {
    administratorLogin: 'adminuser'
    administratorLoginPassword: 'Password123!'
  }
}

resource sqlDb 'Microsoft.Sql/servers/databases@2023-05-01-preview' = {
  parent: sqlServer
  name: 'sqlDb'
  location: location
  sku: {
    name: 'Basic'
  }
}
