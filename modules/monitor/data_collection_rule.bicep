param deploymentParams object
param tags object = resourceGroup().tags
param osKind string
param ruleName string
param logFilePattern string
param customTableNamePrefix string
param dataCollectionEndpointId string
param logAnalyticsPayGWorkspaceId string
param logAnalyticsPayGWorkspaceName string

resource r_dcr 'Microsoft.Insights/dataCollectionRules@2021-09-01-preview' = {
  name: '${ruleName}_${deploymentParams.global_uniqueness}'
  location: deploymentParams.location
  tags: tags
  kind: osKind
  properties: {
    description: 'Log collection rule for miztiik web store data across all linux Vms.'
    dataCollectionEndpointId: dataCollectionEndpointId
    streamDeclarations: {
      'Custom-${customTableNamePrefix}_CL': {
        columns: [
          {
            name: 'TimeGenerated'
            type: 'datetime'
          }
          {
            name: 'RawData'
            type: 'string'
          }
          {
            name: 'request_id'
            type: 'string'
          }
          {
            name: 'event_type'
            type: 'string'
          }
          {
            name: 'store_id'
            type: 'int'
          }
          {
            name: 'cust_id'
            type: 'int'
          }
          {
            name: 'category'
            type: 'string'
          }
          {
            name: 'sku'
            type: 'int'
          }
          {
            name: 'price'
            type: 'real'
          }
          {
            name: 'qty'
            type: 'int'
          }
          {
            name: 'discount'
            type: 'real'
          }
          {
            name: 'gift_wrap'
            type: 'boolean'
          }
          {
            name: 'variant'
            type: 'string'
          }
          {
            name: 'priority_shipping'
            type: 'boolean'
          }
          {
            name: 'contact_me'
            type: 'string'
          }
        ]
      }
    }
    dataSources: {
      logFiles: [
        {
          streams: [
            'Custom-${customTableNamePrefix}_CL'
          ]
          filePatterns: [
            logFilePattern
          ]
          format: 'text'
          settings: {
            text: {
              recordStartTimestampFormat: 'ISO 8601'
            }
          }
          // name: '${customTableNamePrefix}_CL'
          name: 'myFancyLogFileFormat'
        }
      ]
    }
    destinations: {
      logAnalytics: [
        {
          name: logAnalyticsPayGWorkspaceName
          workspaceResourceId: logAnalyticsPayGWorkspaceId
        }
      ]
    }
    dataFlows: [
      {
        streams: [ 'Custom-${customTableNamePrefix}_CL' ]
        destinations: [ logAnalyticsPayGWorkspaceName ]
        transformKql: 'source | extend jsonContext = parse_json(tostring(RawData)) | extend TimeGenerated=now(), request_id=tostring(RawData), event_type=tostring(jsonContext.event_type), store_id=toint(jsonContext.store_id),cust_id=toint(jsonContext.cust_id),category=tostring(jsonContext.category),sku=toint(jsonContext.sku),price=toreal(jsonContext.price),qty=toint(jsonContext.qty),discount=toreal(jsonContext.discount),gift_wrap=tobool(jsonContext.gift_wrap),variant=tostring(jsonContext.variant),priority_shipping=tobool(jsonContext.priority_shipping),contact_me=tostring(jsonContext.contact_me)'
        outputStream: 'Custom-${customTableNamePrefix}_CL'
      }
    ]
  }
}

output dataCollectionRuleId string = r_dcr.id
