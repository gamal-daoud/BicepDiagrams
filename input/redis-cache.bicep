param location string = resourceGroup().location

resource redisCache 'Microsoft.Cache/redis@2023-08-01' = {
  name: 'myRedisCache'
  location: location
  properties: {
    sku: {
      name: 'Basic'
      family: 'C'
      capacity: 0
    }
    enableNonSslPort: false
  }
}
