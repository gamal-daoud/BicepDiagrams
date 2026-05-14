
resource mysqlDb 'Microsoft.Sql/servers/databases@2023-05-01-preview' = {
  name: 'MyServer/WordPressDB'
  location: 'eastus'
}

resource dbNsgNode 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: 'DBSecurityGroup'
  location: 'eastus'
    
}
