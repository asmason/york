
// Scope
targetScope = 'resourceGroup'

// Parameters
@minLength(6)
@maxLength(20)
@description('Specifies the name of the storage account')
param storageAccountName string

@description('Specifies the location for all resources.')
param location string

@description('Specifies the tags.')
param tags object = {}

@description('Storage account sku')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
  'Standard_ZRS'
  'Premium_LRS'
  'Premium_ZRS'
  'Standard_GZRS'
  'Standard_RAGZRS'
])
param storageSku string = 'Standard_LRS'

@description('Specifies the Storage account kind')
@allowed([
  'Storage'
  'StorageV2'
  'BlobStorage'
  'FileStorage'
  'BlockBlobStorage'
])
param storageKind string = 'StorageV2'

@description('Specifies the Storage account access tier, Hot for frequently accessed data or Cool for infreqently accessed data')
@allowed([
  'Hot'
  'Cool'
])
param storageTier string = 'Hot'

@description('Enable blob service encryption')
param enableBlobServiceEncryption bool = true

@description('Enable file service encryption')
param enableFileServiceEncryption bool = true

@description('Enable queue service encryption')
param enableQueueServiceEncryption bool = true

@description('Enable table service encryption')
param enableTableServiceEncryption bool = true

@description('Enable hierarchical namespace (data lake service)')
param enableHierarchicalNamespace bool = false

@description('NFS 3.0 protocol support enabled if set to true.')
param enableNfsV3 bool = false

@description('SFTP protocol support enabled if set to true.')
param enableSftp bool = false

@description('SFTP user name.')
param sftpUserName string = 'sftpuser'

@description('The name of the container -- the "root" -- folder in the ADLS hierarchy.')
param sftpRootContainterName string = 'sftp'

@description('SFTP SSH Public Key for primary user. If not specified, Azure will generate a password which can be accessed securely')
param sftpSshPublicKey string = ''

@description('An array of IPv4 addresses to be whitelisted for access to this SFTP storage account and container. Do not specify RFC 1918 addresses nor CIDRs smaller than /30. This should be a list of the IPs representing machines at the other end of the SFTP transfer.')
param sftpWhiteListedIps array = []

@description('Specifies the network acl default action. Set to Deny if using SFTP IP whitelist.')
@allowed([
  'Allow'
  'Deny'
])
param networkAclDefaultAction string = 'Allow'

@description('Specifies the network endpoint type.')
@allowed([
  'PublicEndpoint'
  'ServiceEndpoint'
  'PrivateEndpoint'
])
param networkEndpointType string = 'PublicEndpoint'

@minLength(6)
@maxLength(30)
@description('Specifes the virtual network resource group name.')
param virtualNetworkResourceGroupName string

@minLength(6)
@maxLength(30)
@description('Specifes the virtual network name.')
param virtualNetworkName string

@minLength(6)
@maxLength(30)
@description('Specifes the virtual network subnet name.')
param virtualNetworkSubnetName string

@description('Allow large file shares if sets to Enabled. It cannot be disabled once it is enabled.')
param largeFileSharesState string = 'Disabled'

@description('Set the minimum TLS version to be permitted on requests to storage.')
param minimumTlsVersion string = 'TLS1_2'

@description('Allows https traffic only to storage service if sets to true.')
param supportsHttpsTrafficOnly bool = true

@description('Enable lifecycle management policy')
param enableLifecycleManagementPolicy bool = false

@description('If lifecycle management policy enabled, then number of days before tier is moved from Hot to Cool')
param tierToCoolNumDays int = 90

@description('Enable container delete retention policy')
param enableContainerDeleteRetentionPolicy bool = true

@description('Number of day retention if container delete policy enabled')
param containerDeleteRetentionPolicyNumDays int = 7

@description('Array of container names to create within the storage account')
param containerNames array = []

@description('Array of share names to create within the storage account')
param shareNames array = []

@description('Specifies whether public access is permitted on blob')
param allowBlobPublicAccess bool = true

@description('Specifies whether infrastructure encryption is required using platform managed keys.')
param requireInfrastructureEncryption bool = false

@description('Resource Group of existing log analytics workspace.')
param existingLogWorkspaceResourceGroup string

@description('Existing log analytics workspace name.')
param existingLogWorkspaceName string

@description('Specifies whether to default to AAD authentication in the Azure Portal.')
param defaultToOAuthAuthentication bool = true

@description('Specifies whether to allow shared key access.')
param allowSharedKeyAccess bool = true


resource existingVirtualNetwork 'Microsoft.Network/virtualNetworks@2021-08-01' existing = if(networkEndpointType != 'PublicEndpoint'){
  scope: resourceGroup(virtualNetworkResourceGroupName)
  name: virtualNetworkName
}

resource existingSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' existing = if(networkEndpointType != 'PublicEndpoint'){
  name: virtualNetworkSubnetName
  parent:existingVirtualNetwork
}


// Resources
resource storage 'Microsoft.Storage/storageAccounts@2021-08-01' = {
  name: storageAccountName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: storageSku
  }
  kind: storageKind
  properties: {
    accessTier: storageTier
    allowBlobPublicAccess: networkEndpointType == 'PrivateEndpoint' ? false : allowBlobPublicAccess
    allowSharedKeyAccess: allowSharedKeyAccess
    defaultToOAuthAuthentication:defaultToOAuthAuthentication
    azureFilesIdentityBasedAuthentication: {
      directoryServiceOptions: 'AADKERB'
    }
    encryption: {
      keySource: 'Microsoft.Storage'
      requireInfrastructureEncryption: requireInfrastructureEncryption
      services: {
        blob: {
          enabled: enableBlobServiceEncryption
        }
        file: {
          enabled: enableFileServiceEncryption
        }
        queue: {
          enabled: enableQueueServiceEncryption
        }
        table: {
          enabled: enableTableServiceEncryption
        }
      }
    }
    networkAcls: {
      defaultAction: networkEndpointType == 'PrivateEndpoint' || networkEndpointType == 'ServiceEndpoint' ? 'Deny' : networkAclDefaultAction
      bypass: 'AzureServices,Logging,Metrics' // Allow Azure services to access the storage account
      virtualNetworkRules: networkEndpointType == 'ServiceEndpoint' ? [{
        id: existingSubnet.id
        action: 'Allow'
      }] : []
      ipRules: [for ip in sftpWhiteListedIps: {
        // An array of public IP addresses that are allowed to send/receive files via SFTP in this storage account
        value: ip
        action: 'Allow'
      }]
    }
    isHnsEnabled: enableHierarchicalNamespace
    isNfsV3Enabled: enableNfsV3
    isSftpEnabled: enableSftp
    largeFileSharesState: largeFileSharesState
    minimumTlsVersion: minimumTlsVersion
    supportsHttpsTrafficOnly: supportsHttpsTrafficOnly
  }
  // shares
  resource fileService 'fileServices' = {
    name: 'default'

    resource share 'shares' = [for name in shareNames: {
      name: name
      properties:{
        shareQuota : 128  
      }
    }]
  }
}

// assign management policies
resource storageManagementPolicies 'Microsoft.Storage/storageAccounts/managementPolicies@2021-08-01' = {
  parent: storage
  name: 'default'
  properties: {
    policy: {
      rules: [
        {
          enabled: enableLifecycleManagementPolicy
          name: 'default'
          type: 'Lifecycle'
          definition: {
            actions: {
              baseBlob: {
                tierToCool: {
                  daysAfterModificationGreaterThan: tierToCoolNumDays
                }
              }
              snapshot: {
                tierToCool: {
                  daysAfterCreationGreaterThan: tierToCoolNumDays
                }
              }
              version: {
                tierToCool: {
                  daysAfterCreationGreaterThan: tierToCoolNumDays
                }
              }
            }
            filters: {
              blobTypes: [
                'blockBlob'
              ]
              prefixMatch: []
            }
          }
        }
      ]
    }
  }
}

// assign container delete retention policy
resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2021-06-01' = {
  parent: storage
  name: 'default'
  properties: {
    containerDeleteRetentionPolicy: {
      enabled: enableContainerDeleteRetentionPolicy
      days: containerDeleteRetentionPolicyNumDays
    }
    cors: {
      corsRules: []
    }
  }
}

// add containers to the storage account
resource blobServicesContainers 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-06-01' = [for containerName in containerNames: {
  parent: blobServices
  name: containerName
  properties: {
    publicAccess: 'None'
    metadata: {}
  }
}]

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2021-06-01' existing = {
  name: 'default'
  parent: storage
}

resource existingLogAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = if (length(existingLogWorkspaceName) > 0) {
  scope: resourceGroup(existingLogWorkspaceResourceGroup)
  name: existingLogWorkspaceName
}

// Assign diagnostic settings to log analytics if required
resource storageDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (length(existingLogWorkspaceName) > 0) {
  dependsOn: [
    blobService
  ]
  scope: blobService
  name: 'blobdiagnostics'
  properties: {
    workspaceId: existingLogAnalyticsWorkspace.id
    logs: [
      {
        category: 'StorageRead'
        enabled: true
      }
      {
        category: 'StorageWrite'
        enabled: true
      }
      {
        category: 'StorageDelete'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'Transaction'
        enabled: true
      }
    ]    
  }
}

resource advancedThreatProtectionSettings 'Microsoft.Security/advancedThreatProtectionSettings@2019-01-01' = {
  name: 'current'
  scope: storage
  properties: {
    isEnabled: true
  }
}

var sftpHomeDirectory = 'sftp/'
resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-08-01'  = if (enableSftp == true) {
  name: '${storage.name}/default/${sftpHomeDirectory}'
  properties: {
    publicAccess: 'Container'
  }

}

resource sftpLocalUser 'Microsoft.Storage/storageAccounts/localUsers@2021-08-01' = if (enableSftp == true) {
  name: sftpUserName // Do not change this parameter, which is set to 'sftpuser'
  parent: storage
  properties: {
    permissionScopes: [
      {
        permissions: 'rcwdl'
        service: 'blob'
        resourceName: sftpRootContainterName
      }
    ]
    // homeDirectory is set to the 'root' directory, which is named 'sftp'. Note the '/' which is required
    homeDirectory: sftpHomeDirectory 
    // The other end of the SFTP connection must supply an OpenSSH-generated (or compatible) public key
    sshAuthorizedKeys: empty(sftpSshPublicKey) ? null : [
      {
        description: '${sftpUserName} public key'
        key: sftpSshPublicKey
      }
    ]
    hasSharedKey: false
  }
}


// Outputs
var accountKey = storage.listKeys().keys[0].value
var blobStorageConnectionString  = 'DefaultEndpointsProtocol=https;AccountName=${storage.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(storage.id, storage.apiVersion).keys[0].value}'
output storageId string = storage.id
output storageFileSystemIds array = [for containerName in containerNames: {
  storageFileSystemId: resourceId('Microsoft.Storage/storageAccounts/blobServices/containers', storageAccountName, 'default', containerName)
}]
output blobConnectionString string = blobStorageConnectionString
output accountKey string = accountKey
