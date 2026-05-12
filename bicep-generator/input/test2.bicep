resource aks 'Microsoft.ContainerService/managedClusters@2023-03-01' = {
  name: 'myAksCluster'
  location: resourceGroup().location
  properties: {
    dnsPrefix: 'myaks'
    agentPoolProfiles: [
      {
        name: 'nodepool1'
        count: 2
        vmSize: 'Standard_DS2_v2'
        mode: 'System'
      }
    ]
  }
}

resource k8sConfig 'Microsoft.KubernetesConfiguration/fluxConfigurations@2022-03-01' = {
  name: 'wordpress-config'
  scope: aks
  properties: {
    namespace: 'default'
    sourceKind: 'GitRepository'
    gitRepository: {
      url: 'https://github.com/monrepo/wordpress-k8s'
      branch: 'main'
    }
  }
}
