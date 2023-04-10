param deploymentParams object
param storageAccountParams object
param tags object = resourceGroup().tags

// var = uniqStr2 = guid(resourceGroup().id, "asda")
var uniqStr = substring(uniqueString(resourceGroup().id), 0, 6)
var saName = '${storageAccountParams.storageAccountNamePrefix}${uniqStr}${deploymentParams.global_uniqueness}'

resource r_sa 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: saName
  location: deploymentParams.location
  tags: tags
  sku: {
    name: '${storageAccountParams.sku}'
  }
  kind: '${storageAccountParams.kind}'
  properties: {
    minimumTlsVersion: '${storageAccountParams.minimumTlsVersion}'
    allowBlobPublicAccess: storageAccountParams.allowBlobPublicAccess
    supportsHttpsTrafficOnly: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
  }
}

// Create a blob storage container in the storage account
resource r_blobSvc 'Microsoft.Storage/storageAccounts/blobServices@2021-06-01' = {
  parent: r_sa
  name: 'default'
}

resource r_blobContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-04-01' = {
  parent: r_blobSvc
  name: '${storageAccountParams.blobNamePrefix}-${deploymentParams.global_uniqueness}'
  properties: {
    publicAccess: 'None'
  }
}

output saName string = r_sa.name
output saPrimaryEndpointsBlob string = r_sa.properties.primaryEndpoints.blob
output saPrimaryEndpoints object = r_sa.properties.primaryEndpoints

output blobContainerId string = r_blobContainer.id
output blobContainerName string = r_blobContainer.name
