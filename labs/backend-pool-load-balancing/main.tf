terraform {
  required_providers {
    azapi = {
      source  = "Azure/azapi"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscriptionId
}

variable "subscriptionId" {
  description = "Subscription id"
  type        = string
}

variable "mockWebApps" {
  description = "List of Mock webapp names used to simulate OpenAI behavior."
  type        = list(any)
  default     = []
}

variable "mockBackendPoolName" {
  description = "The name of the OpenAI mock backend pool"
  type        = string
  default     = "openai-backend-pool"
}

variable "mockBackendPoolDescription" {
  description = "The description of the OpenAI mock backend pool"
  type        = string
  default     = "Load balancer for multiple OpenAI Mocking endpoints"
}

variable "openAIConfig" {
  description = "List of OpenAI resources to create. Add pairs of name and location."
  type        = list(any)
  default     = []
}

variable "openAIDeploymentName" {
  description = "Deployment Name"
  type        = string
}

variable "openAISku" {
  description = "Azure OpenAI Sku"
  type        = string
  default     = "S0"
  validation {
    condition     = contains(["S0"], var.openAISku)
    error_message = "Invalid SKU. Allowed values are: S0"
  }
}

variable "openAIModelName" {
  description = "Model Name"
  type        = string
}

variable "openAIModelVersion" {
  description = "Model Version"
  type        = string
}

variable "openAIModelCapacity" {
  description = "Model Capacity"
  type        = number
  default     = 20
}

variable "apimResourceName" {
  description = "The name of the API Management resource"
  type        = string
}

variable "resourceGroupName" {
  description = "The name of the resource group in which to create the APIM service"
  type        = string
}

variable "apimResourceLocation" {
  description = "Location for the APIM resource"
  type        = string
  default     = ""
}

variable "apimSku" {
  description = "The pricing tier of this API Management service"
  type        = string
  default     = "Consumption"
  validation {
    condition     = contains(["Consumption", "Developer", "Basic", "Basicv2", "Standard", "Standardv2", "Premium"], var.apimSku)
    error_message = "Invalid SKU. Allowed values are: Consumption, Developer, Basic, Basicv2, Standard, Standardv2, Premium"
  }
}

variable "apimSkuCount" {
  description = "The instance size of this API Management service."
  type        = number
  default     = 1
  validation {
    condition     = contains([0, 1, 2], var.apimSkuCount)
    error_message = "Invalid SKU count. Allowed values are: 0, 1, 2"
  }
}

variable "apimPublisherEmail" {
  description = "The email address of the owner of the service"
  type        = string
  default     = "noreply@microsoft.com"
}

variable "apimPublisherName" {
  description = "The name of the owner of the service"
  type        = string
  default     = "Microsoft"
}

variable "openAIAPIName" {
  description = "The name of the APIM API for OpenAI API"
  type        = string
  default     = "openai"
}

variable "openAIAPIPath" {
  description = "The relative path of the APIM API for OpenAI API"
  type        = string
  default     = "openai"
}

variable "openAIAPIDisplayName" {
  description = "The display name of the APIM API for OpenAI API"
  type        = string
  default     = "OpenAI"
}

variable "openAIAPIDescription" {
  description = "The description of the APIM API for OpenAI API"
  type        = string
  default     = "Azure OpenAI API inferencing API"
}

variable "openAIAPISpecURL" {
  description = "Full URL for the OpenAI API spec"
  type        = string
  default     = "https://raw.githubusercontent.com/Azure/azure-rest-api-specs/main/specification/cognitiveservices/data-plane/AzureOpenAI/inference/stable/2024-02-01/inference.json"
}

variable "openAISubscriptionName" {
  description = "The name of the APIM Subscription for OpenAI API"
  type        = string
  default     = "openai-subscription"
}

variable "openAISubscriptionDescription" {
  description = "The description of the APIM Subscription for OpenAI API"
  type        = string
  default     = "OpenAI Subscription"
}

variable "openAIBackendPoolName" {
  description = "The name of the OpenAI backend pool"
  type        = string
  default     = "openai-backend-pool"
}

variable "openAIBackendPoolDescription" {
  description = "The description of the OpenAI backend pool"
  type        = string
  default     = "Load balancer for multiple OpenAI endpoints"
}

data "azurerm_subscription" "current" {}

data "azurerm_resource_group" "rg" {
  name = var.resourceGroupName
}

locals {
  resource_suffix = substr(md5("${data.azurerm_subscription.current.subscription_id}${data.azurerm_resource_group.rg.id}"), 0, 8)
}

resource "azurerm_cognitive_account" "openai" {
  for_each = { for config in var.openAIConfig : config.name => config if length(var.openAIConfig) > 0 }

  name                = "${each.value.name}-${local.resource_suffix}"
  location            = each.value.location
  resource_group_name = var.resourceGroupName
  kind                = "OpenAI"
  sku_name            = var.openAISku
  custom_subdomain_name = lower("${each.value.name}-${local.resource_suffix}")
}

resource "azurerm_cognitive_deployment" "openai_deployment" {
  for_each = { for config in var.openAIConfig : config.name => config if length(var.openAIConfig) > 0 }

  name                = var.openAIDeploymentName
  cognitive_account_id = azurerm_cognitive_account.openai[each.key].id

  model {
    format  = "OpenAI"
    name    = var.openAIModelName
    version = var.openAIModelVersion
  }

  sku {
    name     = "Standard"
    capacity = var.openAIModelCapacity
  }
}

resource "azapi_resource" "apim" {
  type      = "Microsoft.ApiManagement/service@2023-09-01-preview"
  name      = "${var.apimResourceName}-${local.resource_suffix}"
  location  = (var.apimResourceLocation == "") ? data.azurerm_resource_group.rg.location : var.apimResourceLocation
  parent_id = data.azurerm_resource_group.rg.id
  identity {
    type = "SystemAssigned"
  }
  body = jsonencode({
    sku = {
      capacity = (var.apimSku == "Consumption") ? 0 : ((var.apimSku == "Developer") ? 1 : var.apimSkuCount)
      name     = var.apimSku
    }
    properties = {
      publisherName  = var.apimPublisherName
      publisherEmail = var.apimPublisherEmail  
    }
  })  
}

resource "azurerm_role_assignment" "apim_role" {
  for_each = { for config in var.openAIConfig : config.name => config if length(var.openAIConfig) > 0 }

  scope                = azurerm_cognitive_account.openai[each.key].id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = azapi_resource.apim.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_api_management_api" "openai_api" {
  name                = var.openAIAPIName
  resource_group_name = var.resourceGroupName
  api_management_name = azapi_resource.apim.name
  revision            = "1"
  api_type            = "http"
  description         = var.openAIAPIDescription  
  display_name        = var.openAIAPIDisplayName
  path                = var.openAIAPIPath
  protocols           = ["https"]
  import {
    content_format = "openapi-link"
    content_value  = var.openAIAPISpecURL
  }  
  subscription_key_parameter_names {
    header = "api-key"
    query = "api-key"
  }
  subscription_required = true
}

resource "azurerm_api_management_api_policy" "openai_api_policy" {
  api_name            = azurerm_api_management_api.openai_api.name
  api_management_name = azapi_resource.apim.name
  resource_group_name = var.resourceGroupName
  xml_content         = file("policy.xml")
}

resource "azapi_resource" "openai_backend" {
  for_each = { for config in var.openAIConfig : config.name => config if length(var.openAIConfig) > 0 }

  type = "Microsoft.ApiManagement/service/backends@2023-09-01-preview"
  name = each.value.name
  parent_id = azapi_resource.apim.id
  body = jsonencode({
    properties = {
      description = "backend description"
      url = "${azurerm_cognitive_account.openai[each.key].endpoint}openai"
      protocol = "http"      
      circuitBreaker = {
        rules = [
          {
            failureCondition = {
                count        = 1
                errorReasons = ["Server errors"]
                interval     = "PT510S"
                statusCodeRanges = [
                  {
                    min = 429
                    max = 429
                  }
                ]
            }
            name             = "openAIBreakerRule"
            tripDuration     = "PT510S"
            acceptRetryAfter = true
          }
        ]
      }
    }
  })
}

resource "azapi_resource" "mock_backend" {
  for_each = { for mock in var.mockWebApps : mock.name => mock if length(var.openAIConfig) == 0 && length(var.mockWebApps) > 0 }

  type = "Microsoft.ApiManagement/service/backends@2023-09-01-preview"
  name = each.value.name
  parent_id = azapi_resource.apim.id
  body = jsonencode({
    properties = {
      description = "backend description"      
      url = "${each.value.endpoint}/openai"
      protocol = "http"
      circuitBreaker = {
        rules = [
          {
            failureCondition = {
                count        = 3
                errorReasons = ["Server errors"]
                interval     = "PT510S"
                statusCodeRanges = [
                  {
                    min = 429
                    max = 429
                  }
                ]
            }
            name             = "mockBreakerRule"
            tripDuration     = "PT510S"
            acceptRetryAfter = true
          }
        ]
      }
    }
  })
}

resource "azapi_resource" "openai_backend_pool" {
  count = length(var.openAIConfig) > 1 ? 1 : 0 
  type = "Microsoft.ApiManagement/service/backends@2023-09-01-preview"
  name = var.openAIBackendPoolName
  parent_id = azapi_resource.apim.id
  body = jsonencode({
    properties = {
      description = var.openAIBackendPoolDescription
      type = "Pool"        
      pool = {
        services = [for config in var.openAIConfig : {
            id       = "/backends/${azapi_resource.openai_backend[config.name].name}"
            priority = config.priority
            weight   = config.weight
        }]
      }
    }
  })
  schema_validation_enabled = false
}

resource "azapi_resource" "mock_backend_pool" {
  count = length(var.openAIConfig) == 0 && length(var.mockWebApps) > 1 ? 1 : 0
  type = "Microsoft.ApiManagement/service/backends@2023-09-01-preview"
  name = var.mockBackendPoolName
  parent_id = azapi_resource.apim.id
  body = jsonencode({
    properties = {
      description = var.mockBackendPoolDescription
      type = "Pool"        
      pool = {
        services = [for mock in var.mockWebApps : {
            id       = "/backends/${azapi_resource.mock_backend[mock.name].name}"
            priority = mock.priority
            weight   = mock.weight
        }]
      }
    }
  })
  schema_validation_enabled = false
}

resource "azurerm_api_management_subscription" "openai_subscription" {
  resource_group_name = var.resourceGroupName
  api_management_name = azapi_resource.apim.name
  allow_tracing       = true
  display_name        = var.openAISubscriptionName
  api_id              = "${azapi_resource.apim.id}/apis/${azurerm_api_management_api.openai_api.name}"
  state               = "active"  
}

output "apimServiceId" {
  value = azapi_resource.apim.id
}

output "apimResourceGatewayURL" {
  value = "https://${azapi_resource.apim.name}.azure-api.net"
}

output "apimSubscriptionKey" {
  value     = azurerm_api_management_subscription.openai_subscription.primary_key
  sensitive = true
}