# How to Run this File

## Login to Azure on VSCode
```
az login --tenant TENANT_ID
az account set --subscription "subscription-id-or-name" 
```
## Confirm Account
```
az account show
```

# Create Resource Group
```
az group create \
  --name rg-currencyconverter \
  --location eastus
```

## Deploy your BICEP File
*Remember to cd into the file folder* - `cd currencyconverter-for-azureclassdemo/infa `

```
az deployment group create \
  --resource-group rg-currencyconverter \
  --template-file main.bicep \
  --parameters environmentName=dev
```

## Confirm your Resources are Created, after use delete the resource group and everything deletes
```
az group delete \
  --name rg-currencyconverter \
  --yes
```


## Star this Repo a Star, if it was helpful , THANK YOU
