param deploymentParams object
param vmParams object
param saName string
param blobContainerName string
param saPrimaryEndpointsBlob string
param tags object = resourceGroup().tags
param vnetName string
param dataCollectionEndpointId string
param dataCollectionRuleId string

param vmName string = '${vmParams.vmNamePrefix}-${deploymentParams.global_uniqueness}'

param dnsLabelPrefix string = toLower('${vmParams.vmNamePrefix}-${deploymentParams.global_uniqueness}-${uniqueString(resourceGroup().id, vmName)}')
param publicIpName string = '${vmParams.vmNamePrefix}-${deploymentParams.global_uniqueness}-PublicIp'

// var userDataScript = base64(loadTextContent('./bootstrap_scripts/deploy_app.sh'))
var userDataScript = loadFileAsBase64('./bootstrap_scripts/deploy_app.sh')

// @description('VM auth')
// @allowed([
//   'sshPublicKey'
//   'password'
// ])
// param authType string = 'password'

var LinuxConfiguration = {
  disablePasswordAuthentication: true
  ssh: {
    publickeys: [
      {
        path: '/home/${vmParams.adminUsername}/.ssh/authorized_keys'
        keyData: vmParams.adminPassword
      }
    ]
  }
}

resource r_publicIp 'Microsoft.Network/publicIPAddresses@2022-05-01' = {
  name: publicIpName
  location: deploymentParams.location
  tags: tags
  sku: {
    name: vmParams.publicIpSku
  }
  properties: {
    publicIPAllocationMethod: vmParams.publicIPAllocationMethod
    publicIPAddressVersion: 'IPv4'
    deleteOption: 'Delete'
    dnsSettings: {
      domainNameLabel: dnsLabelPrefix
    }
  }
}

resource r_webSg 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: 'webSg'
  location: deploymentParams.location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowInboundSsh'
        properties: {
          priority: 250
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
      {
        name: 'HTTP'
        properties: {
          priority: 200
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
        }
      }
      {
        name: 'Outbound_Allow_All'
        properties: {
          priority: 300
          protocol: '*'
          access: 'Allow'
          direction: 'Outbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
      {
        name: 'AzureResourceManager'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'AzureResourceManager'
          access: 'Allow'
          priority: 160
          direction: 'Outbound'
        }
      }
      {
        name: 'AzureStorageAccount'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Storage.${deploymentParams.location}'
          access: 'Allow'
          priority: 170
          direction: 'Outbound'
        }
      }
      {
        name: 'AzureFrontDoor'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'AzureFrontDoor.FrontEnd'
          access: 'Allow'
          priority: 180
          direction: 'Outbound'
        }
      }
    ]
  }
}

// Create NIC for the VM
resource r_nic_01 'Microsoft.Network/networkInterfaces@2022-05-01' = {
  name: '${vmName}-Nic-01'
  location: deploymentParams.location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, vmParams.vmSubnetName)
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: r_publicIp.id
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: r_webSg.id
    }
  }
}

// Create User-Assigned Identity
resource r_vmIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${vmName}_${deploymentParams.global_uniqueness}_Identity'
  location: deploymentParams.location
  tags: tags
}

// Add permissions to the custom identity to write to the blob storage
// https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles

param blobOwnerRoleId string = 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'

// resource r_attachBlobContributorPermsToRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
//   name: guid('r_attachBlobContributorPermsToRole', r_vmIdentity.id, blobOwnerRoleId)
//   properties: {
//     description: 'Blob Contributor Permission to ResourceGroup scope'
//     roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', blobOwnerRoleId)
//     principalId: r_vmIdentity.properties.principalId
//     principalType: 'ServicePrincipal'
//     // principalType: 'User'
//     // https://learn.microsoft.com/en-us/azure/role-based-access-control/troubleshooting?tabs=bicep#symptom---assigning-a-role-to-a-new-principal-sometimes-fails
//   }
// }


var conditionStr1= '((!(ActionMatches{\'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read\'}) AND !(ActionMatches{\'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/write\'}) ) OR (@Resource[Microsoft.Storage/storageAccounts/blobServices/containers:name] StringEquals \'${blobContainerName}\'))'


// Refined Scope with conditions
// https://learn.microsoft.com/en-us/azure/templates/microsoft.authorization/roleassignments?pivots=deployment-language-bicep
resource r_attachBlobContributorPermsToRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('r_attachBlobContributorPermsToRole', r_vmIdentity.id, blobOwnerRoleId)
  scope: r_blobContainerRef
  properties: {
    description: 'Blob Contributor Permission to ResourceGroup scope'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', blobOwnerRoleId)
    principalId: r_vmIdentity.properties.principalId
    conditionVersion: '2.0'
    condition: conditionStr1
    // condition: '@Resource [Microsoft.Storage/storageAccounts/blobServices/containers:ContainerName] StringEqualsIgnoreCase ${blobContainerName} && @ResourceAction Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read && @ResourceAction Microsoft.Storage/storageAccounts/blobServices/containers/blobs/write'
    // condition: 'startsWith(field(\'Microsoft.Storage/storageAccounts/blobServices/containers/name\'), \'${blobContainerName}\') && contains(field(\'Microsoft.Storage/storageAccounts/blobServices/containers/actions\'), \'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read\') && contains(field(\'Microsoft.Storage/storageAccounts/blobServices/containers/actions\'), \'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/write\')'

    /*
    or(
      and(
        not(actionMatches('Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read')),
        not(actionMatches('Microsoft.Storage/storageAccounts/blobServices/containers/blobs/write'))
      ),
      equals(resourceId('Microsoft.Storage/storageAccounts/blobServices/containers', 'store-events-009'), 
             '[tolower(@substring(resourceId(),add(length(resourceId(''Microsoft.Storage/storageAccounts/blobServices/containers'')),2)),sub(length(resourceId()),length(resourceId(''Microsoft.Storage/storageAccounts/blobServices/containers''))))]')
    )
*/


    principalType: 'ServicePrincipal'
    // principalType: 'User'
    // https://learn.microsoft.com/en-us/azure/role-based-access-control/troubleshooting?tabs=bicep#symptom---assigning-a-role-to-a-new-principal-sometimes-fails
  }
}

resource r_blobContainerRef 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-04-01' = {
  name: '${saName}/default/${blobContainerName}'
}

// Add Permissions scoped to resource
// retrieve the ID of the Storage Blob Data Contributor role definition
param blobContributorRoleId string = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
resource r_attachBlobDataPermsToRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('r_attachBlobDataPermsToRole', r_vmIdentity.id, blobOwnerRoleId)
  scope: r_blobContainerRef
  properties: {
    description: 'Blob Contributor Permission to Resource scope'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', blobContributorRoleId)
    principalId: r_vmIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}


resource r_vm 'Microsoft.Compute/virtualMachines@2022-03-01' = {
  name: vmName
  location: deploymentParams.location
  tags: tags
  identity: {
    // type: 'SystemAssigned'
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${r_vmIdentity.id}': {}
    }
  }
  // zones: [
  //   '3'
  // ]
  properties: {
    hardwareProfile: {
      vmSize: vmParams.vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: vmParams.adminUsername
      adminPassword: vmParams.adminPassword.secureString
      linuxConfiguration: ((vmParams.authType == 'password') ? null : LinuxConfiguration)
    }
    storageProfile: {
      imageReference: ((vmParams.isUbuntu == true) ? ({
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }) : ({
        publisher: 'RedHat'
        offer: 'RHEL'
        sku: '91-gen2'
        version: 'latest'
      }))
      osDisk: {
        createOption: 'FromImage'
        name: '${vmName}_osDisk'
        caching: 'ReadWrite'
        deleteOption: 'Delete'
        diskSizeGB: 128
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
      dataDisks: [
        {
          createOption: 'Empty'
          name: '${vmName}-DataDisk'
          caching: 'ReadWrite'
          deleteOption: 'Delete'
          lun: 13
          diskSizeGB: 2
          managedDisk: {
            storageAccountType: 'StandardSSD_LRS'
            // storageAccountType: 'PremiumV2_LRS' // Apparently needs zones to be defined and AZURE capacity issues - ^.^
          }
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: r_nic_01.id
        }
      ]
    }
    securityProfile: {
      // encryptionAtHost: true
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: saPrimaryEndpointsBlob
      }
    }
    userData: userDataScript
  }
}

// INSTALL Azure Monitor Agent
resource AzureMonitorLinuxAgent 'Microsoft.Compute/virtualMachines/extensions@2021-07-01' = if (vmParams.isLinux) {
  parent: r_vm
  name: 'AzureMonitorLinuxAgent'
  location: deploymentParams.location
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'AzureMonitorLinuxAgent'
    enableAutomaticUpgrade: true
    autoUpgradeMinorVersion: true
    typeHandlerVersion: '1.25'
    settings: {
      'identifier-name': 'mi_res_id' // Has to be this value
      // 'identifier-value': r_vm.identity.principalId
      'identifier-value': r_vmIdentity.id
    }
  }
}

// Associate Data Collection Rule to VM
resource r_associateVmToDcr 'Microsoft.Insights/dataCollectionRuleAssociations@2021-09-01-preview' = {
  // name: '${vmName}_${deploymentParams.global_uniqueness}'
  name: 'configurationAccessEndpoint'
  scope: r_vm
  properties: {
    dataCollectionEndpointId: dataCollectionEndpointId
    // dataCollectionRuleId: dataCollectionRuleId
    description: 'Send Custom logs to DCR'
  }
}
resource r_associateVmToDcr1 'Microsoft.Insights/dataCollectionRuleAssociations@2021-09-01-preview' = {
  name: '${vmName}_${deploymentParams.global_uniqueness}'
  scope: r_vm
  properties: {
    // dataCollectionEndpointId: dataCollectionEndpointId
    dataCollectionRuleId: dataCollectionRuleId
    description: 'Send Custom logs to DCR'
  }
}

resource windowsAgent 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = if (vmParams.isWindows) {
  name: 'AzureMonitorWindowsAgent'
  parent: r_vm
  location: deploymentParams.location
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'AzureMonitorWindowsAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
  }
}

output webGenHostName string = r_publicIp.properties.dnsSettings.fqdn
output adminUsername string = vmParams.adminUsername
output sshCommand string = 'ssh ${vmParams.adminUsername}@${r_publicIp.properties.dnsSettings.fqdn}'
output webGenHostId string = r_vm.id
output webGenHostPrivateIP string = r_nic_01.properties.ipConfigurations[0].properties.privateIPAddress
output vmIdentityId string = r_vmIdentity.id


output a4 string = '((!(ActionMatches{\'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read\'})) OR (@Resource[Microsoft.Storage/storageAccounts/blobServices/containers:name] StringEquals \'${blobContainerName}\'))'
