# Azure Virtual Machine Access To Blob Storage With User Identity

The developer at Mystique Unicorn are looking for a way store their order events coming from their stores across the world. They are currently using Azure Blob storage for their data lake and would like to store these events there.  A sample of the event is shown below. 

```json
{
    "request_id": "fef1127f-65df-4bca-bc58-e102fb65ee70",
    "store_id": 6,
    "store_fqdn": "m-web-srv-011.internal.cloudapp.net",
    "store_ip": "10.0.0.4",
    "cust_id": 989,
    "category": "Laptops",
    "sku": 126551,
    "price": 10.61,
    "qty": 6,
    "discount": 2.7,
    "gift_wrap": false,
    "variant": "black",
    "priority_shipping": true,
    "ts": "2023-04-10T16:25:04.411091",
    "contact_me": "github.com/miztiik"
}
```

They would like to store the data by date so that they can query them easily. For example query the sales across stores based on store id on a given date. 

Can you show them how the can get started? 

## 🎯 Solutions

To store all the order events, we will create a blob container. To write the events to the container, lets use a user managed identity with it permission scoped narrowly to a specific blob conainer using Azure RBAC.<sup>[1], [2], [3]</sup>.

This repository holds the bicep code to deploy the necessary infrastructure for this demo,
- Virtual Machine(Ubuntu).
  - (_WIP_)Bootstrapped with custom libs using `userData` script.
- Storage Account - `warehouseXXXX`
  - Blob Container - `store-events-xxx`
- User Managed Identity
  - Scoped with contributor privileges with conditional access restricting to a container, (_For ex `store-events-xxx`_)
- Identity attached to the VM


![Miztiik Automaton: Azure Virtual Machine Access To Blob Storage With User Identity](images/miztiik_automation_azure_alert_on_custom_metrics_architecture_0011.png)

1. ## 🧰 Prerequisites

   This demo, instructions, scripts and bicep template is designed to be run in `westeurope`. With few or no modifications you can try it out in other regions as well(_Not covered here_).

   - 🛠 Azure CLI Installed & Configured - [Get help here](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
   - 🛠 Bicep Installed & Configured - [Get help here](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/install)
   - 🛠 VS Code & Bicep Extenstions - [Get help here](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/install#vs-code-and-bicep-extension)

1. ## ⚙️ Setting up the environment

   - Get the application code

     ```bash
     https://github.com/miztiik/azure-vm-to-blob-storage
     cd azure-vm-to-blob-storage
     ```

1. ## 🚀 Prepare the environment

   Let check you have Azure Cli working with 

    ```bash
      # You should have azure cli preinstalled
      az account show
    ```

    You should see an output like this,

   ```json
    {
      "environmentName": "AzureCloud",
      "homeTenantId": "16b30820b6d3",
      "id": "1ac6fdbff37cd9e3",
      "isDefault": true,
      "managedByTenants": [],
      "name": "YOUR-SUBS-NAME",
      "state": "Enabled",
      "tenantId": "16b30820b6d3",
      "user": {
        "name": "miztiik@",
        "type": "user"
      }
    }
   ```

1. ## 🚀 Deploying the application

   Let us walk through each of the stacks,

   - **Stack: Main Bicep**
     The params required for the modules are in `params.json`. Do modify them to suit your need.(_Especially the `adminPassword.secureString` for the VM. You are strongly encouraged to Just-In-Time access or use SSH key instead of password based authentication_). The helper deployment script `deploy.sh` will deploy the `main.bicep` file. This will inturn call the modules for Resource Group(RG), VNet & Virtual Machine, Log analytics workspace, Custom table, Data collection endpoint, Data collection rule(DCR) and finally attach the DCR to the VM.

     **Alert Module**
      We will create a KQL query to identify order events that match the given criteria - 
      
      ```kql
      lumberyardTable001_CL | where discount > 90 and qty >1 and priority_shipping==true
      ```

      We can also refine it to aggregate only the events that had been received in the last `5` minutes like this,
      ```kql
      lumberyardTable001_CL
      | where discount > 90 and qty > 1 and priority_shipping == true
      | where Timestamp > ago(5m)
      ```
      But since have the option of choosing an evaluation frequency within the alert configuration, we will us that. Remember `evaluationFrequency` is smaller than the `aggregation` granularity, this will result in sliding window evaluation. The code is configured for `evaluationFrequency` of `1`minute and  aggregation `windowSize` of `5`minutes, resulting in creating a sliding window. This may also mean we can trigger the alarm multiple times for the event. It is a conscious choice, to balance signal-to-noise towards more noise(aka false-positives) when we are trying to catch suspicious activity.

      ```bash
      sh deploy.sh
      ```

     This stack will create almost all of the resoureces. The RG is created as a deployment at the subscription level. The other resources are deployments at resource group level. 

    - **Virtual Machine**
       A Redhat vm is bootstrapped using `customData` to install python3, git. We will use a bash script `generate_data.sh`. It will generate a json conformant log in this location `/var/log/miztiik-yyyy-MM-dd.json` for example _`/var/log/miztiik-2023-04-03.json`_. All new entries are appended to the file with `new-line` being the delimitter as expected by Azure Custom Logs.

        ```json
        {"request_id": "08b6b258-c6d6-44ff-802e-69d52422095a", "event_type": "inventory_event", "store_id": 45, "cust_id": 4416, "category": "Camera", "sku": 17293, "price": 44.61, "qty": 15
        , "discount": 73.2, "gift_wrap": 0, "variant": "MystiqueAutomatoon", "priority_shipping": 1, "TimeGenerated": "2023-04-03T10:54:23", "contact_me": "github.com/miztiik" }
        {"request_id": "60051c39-6817-4f52-bd8f-59cc9a38be0f", "event_type": "inventory_event", "store_id": 64, "cust_id": 4081, "category": "Camera", "sku": 17815, "price": 50.92, "qty": 16
        , "discount": 29.2, "gift_wrap": 1, "variant": "MystiqueAutomatoon", "priority_shipping": 0, "TimeGenerated": "2023-04-03T10:54:24", "contact_me": "github.com/miztiik" }
        {"request_id": "f340f343-fc0f-40a1-b9f5-2abdd14b929d", "event_type": "inventory_event", "store_id": 35, "cust_id": 338, "category": "Camera", "sku": 16158, "price": 53.76, "qty": 13,
        "discount": 34.3, "gift_wrap": 1, "variant": "MystiqueAutomatoon", "priority_shipping": 0, "TimeGenerated": "2023-04-03T10:54:25", "contact_me": "github.com/miztiik" }
        ```
        
        Formatting a single log line entry properly, will look like this,

        ```json
        {
          "request_id": "f5570d0f-5389-4bce-98c3-7ed5380eefb2",
          "event_type": "inventory_event",
          "store_id": 6,
          "cust_id": 206,
          "category": "Camera",
          "sku": 100657,
          "price": 2.52,
          "qty": 18,
          "discount": 8.2,
          "gift_wrap": true,
          "variant": "red",
          "priority_shipping": true,
          "TimeGenerated": "2021-04-25T12:52:40.938937",
          "contact_me": "github.com/miztiik"
        }
        ```

     After successfully deploying the stack, Check the `Resource Groups/Deployments` section for the resources.


1. ## 🔬 Testing the solution

   - **Connect to the VM**

      Connect to the VM using Just-In-Time access. This should allow your IP/IP list to securelly connect to your VM using private IP address. Use the password you updated in the `params.json`

        ```bash
        ssh miztiik@publicIP
        ```

   - **Generate Log Data**

      For some reason the customData, bootstrap script fails, will fix it later. Until then manually copy the `generate_data.sh` from this repo to the server. _You may need elevated privileges to create log file in `/var/log`.


      ```bash
      sudo su
      cd /var/log/
      # Copy generate_data.sh to the server
      sh generate_data.sh &
      ```

      The script by default is configured to write one log entry every `5` seconds and generate a total `100000` log lines to`/var/log/miztiik*.json`

    
    - **Query in Azure Log Analytics Workspace**

      Login to Azure Log Anaytics portal. You should be able to find it under `/Miztiik_Enterprises_Custom_Logs_To_Monitor_xxx/providers/Microsoft.OperationalInsights/workspaces/lumberyard-payGTier-xxx",`. Navigate to logs, select the custom table(`lumberyardTablexxx_CL`) & `Run`

      ![Miztiik Automaton: Alert on Custom Metrics](images/miztiik_automation_azure_alert_on_custom_metrics_architecture_002.png)
  

  1. **Troubleshooting Azure Monitor Agent**

      - In case if you are facing issues, log into the  VM and check the logs `/var/log/azure/Microsoft.Azure.Monitor.AzureMonitorLinuxAgent/` for potential causes.
      - Check if your account has Azure Data Lake v2 enabled

        ```sh
        az resource show \
          --name  warehousei5chd4011 \
          --resource-group Miztiik_Enterprises_azure_vm_to_blob_storage_011 \
          --resource-type "Microsoft.Storage/storageAccounts" \
          --query properties.isHnsEnabled
        ```
      - List Blob Access

        ```sh
          RG_NAME="MIZTIIK_ENTERPRISES_AZURE_VM_TO_BLOB_STORAGE_011"
          SA_ACCOUNT_NAME="warehousei5chd4011"
          CONTAINER_NAME="store-events-011"
          CONTAINER_NAME1="kuy-muy"

          az storage blob list \
              --container-name ${CONTAINER_NAME1} \
              --account-name ${SA_ACCOUNT_NAME} \
              --auth-mode login

          az storage blob directory list \
              --container-name ${CONTAINER_NAME} \
              -d default \
              --account-name ${SA_ACCOUNT_NAME} \
              --auth-mode login
        ```

        Upload file to blob,

        ```sh
        echo "hello world on $(date +'%Y-%m-%d')" > miztiik.log
        az storage blob upload \
          --account-name ${SA_ACCOUNT_NAME} \
          --container-name ${CONTAINER_NAME} \
          --name miztiik.log \
          --file miztiik.log \
          --auth-mode login
        ```

      
1. ## 📒 Conclusion

    Here we have demonstrated how to configure alerts based on custom logs. You can extend the solution to setup alerts actions groups & receive email notifications. An example of email notification is showin below,

    ![Miztiik Automaton: Alert on Custom Metrics](images/miztiik_automation_azure_alert_on_custom_metrics_architecture_003.png)
  

1. ## 🧹 CleanUp

If you want to destroy all the resources created by the stack, Execute the below command to delete the stack, or _you can delete the stack from console as well_

- Resources created during [Deploying The Application](#-deploying-the-application)
- _Any other custom resources, you have created for this demo_

```bash
# Delete from resource group
az group delete --name Miztiik_Enterprises_xxx --yes
# Follow any on-screen prompt
```

This is not an exhaustive list, please carry out other necessary steps as maybe applicable to your needs.

## 📌 Who is using this

This repository aims to show how to Bicep to new developers, Solution Architects & Ops Engineers in Azure.

### 💡 Help/Suggestions or 🐛 Bugs

Thank you for your interest in contributing to our project. Whether it is a bug report, new feature, correction, or additional documentation or solutions, we greatly value feedback and contributions from our community. [Start here](/issues)

### 👋 Buy me a coffee

[![ko-fi](https://www.ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/Q5Q41QDGK) Buy me a [coffee ☕][900].

### 📚 References


1. [Azure Docs: Azure RBAC][1]
1. [Azure Docs: Azure ABAC][2]
1. [Azure Docs: Azure RBAC Example Conditions][3]
1. [Azure Docs: Azure Monitor Agents -vs- Other Agatnes Overview][2]
1. [Azure Docs: Collect text logs with Azure Monitor Agent][3]
1. [Azure Docs: Collect text logs with Log Analytics Agent][4]
1. [Azure Docs: Custom Table][5]
1. [Azure Docs: Workspace Table Creation][6]
1. [Azure Docs: Log Data Plan Basic-vs-Analytics Comparison][7]
1. [Azure Docs: Custom Log Ingestion using python SDK][8]
1. [Azure Docs: Custom Metrics to Azure Monitor][9]
1. [Azure Docs: Check Logs in Azure Logs][10]
1. [Azure Docs: Troubleshoot Azure Monitor Agent][11]



### 🏷️ Metadata

![miztiik-success-green](https://img.shields.io/badge/Miztiik:Automation:Level-200-blue)

**Level**: 200

[1]: https://learn.microsoft.com/en-us/azure/role-based-access-control/conditions-role-assignments-portal
[2]: https://learn.microsoft.com/en-us/azure/role-based-access-control/conditions-overview
[3]: https://learn.microsoft.com/en-us/azure/storage/blobs/storage-auth-abac-examples?toc=%2Fazure%2Frole-based-access-control%2Ftoc.json

[100]: https://www.udemy.com/course/aws-cloud-security/?referralCode=B7F1B6C78B45ADAF77A9
[101]: https://www.udemy.com/course/aws-cloud-security-proactive-way/?referralCode=71DC542AD4481309A441
[102]: https://www.udemy.com/course/aws-cloud-development-kit-from-beginner-to-professional/?referralCode=E15D7FB64E417C547579
[103]: https://www.udemy.com/course/aws-cloudformation-basics?referralCode=93AD3B1530BC871093D6
[899]: https://www.udemy.com/user/n-kumar/
[900]: https://ko-fi.com/miztiik
[901]: https://ko-fi.com/Q5Q41QDGK