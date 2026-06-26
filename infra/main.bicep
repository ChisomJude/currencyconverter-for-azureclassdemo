// main.bicep
// -------------------------------------------------------------------------
// Provisions Azure infrastructure for the Currency Converter app:
//   - Log Analytics Workspace (telemetry backend)
//   - Azure Container Registry (private image storage)
//   - Azure Container Apps Environment (serverless container hosting)
//
// Used in Day 2 (Module 7: Infrastructure as Code) of the training.
//
// Deploy with:
//   Step 1: Create resource group
//     az group create --name rg-currencyconverter --location eastus
//
//   Step 2: Deploy infrastructure
//     az deployment group create \
//       --resource-group rg-currencyconverter \
//       --template-file infra/main.bicep \
//       --parameters environmentName=dev
// -------------------------------------------------------------------------

@description('Environment name, used to namespace resources (e.g. dev, prod)')
param environmentName string = 'dev'

@description('Azure region for all resources')
param location string = resourceGroup().location

@description('Container image to deploy, e.g. myacr.azurecr.io/currencyconverter:latest')
param containerImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

// ---- Log Analytics Workspace -------------------------------------------
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: 'log-currencyconv-${environmentName}'
  location: location
  tags: {
    environment: environmentName
    createdBy: 'bicep'
    project: 'currencyconverter'
  }
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
  }
}

// ---- Azure Container Registry ------------------------------------------
resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: 'acrcurrencyconv${environmentName}'
  location: location
  tags: {
    environment: environmentName
    createdBy: 'bicep'
    project: 'currencyconverter'
  }
  sku: { name: 'Basic' }
  properties: {
    adminUserEnabled: true
  }
}

// ---- Container Apps Environment ----------------------------------------
resource containerAppEnv 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: 'env-currencyconv-${environmentName}'
  location: location
  tags: {
    environment: environmentName
    createdBy: 'bicep'
    project: 'currencyconverter'
  }
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
  }
}

// ---- Container App -----------------------------------------------------
resource containerApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: 'currencyconverter-app'
  location: location
  tags: {
    environment: environmentName
    createdBy: 'bicep'
    project: 'currencyconverter'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    managedEnvironmentId: containerAppEnv.id
    configuration: {
      ingress: {
        external: true
        targetPort: 8000
        allowInsecure: false
      }
      registries: [
        {
          server: acr.properties.loginServer
          username: acr.listCredentials().username
          passwordSecretRef: 'acr-password'
        }
      ]
      secrets: [
        {
          name: 'acr-password'
          value: acr.listCredentials().passwords[0].value
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'currencyconverter'
          image: containerImage
          env: [
            {
              name: 'PORT'
              value: '8000'
            }
            {
              name: 'FLASK_ENV'
              value: 'production'
            }
          ]
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 3
      }
    }
  }
}

// ---- Outputs -----------------------------------------------------------
output acrLoginServer string = acr.properties.loginServer
output containerAppEnvId string = containerAppEnv.id
output containerAppFqdn string = containerApp.properties.configuration.ingress.fqdn
output containerAppPrincipalId string = containerApp.identity.principalId
