provider "azurerm" {
  features {}
  subscription_id = var.subscriptionId
}

variable "subscriptionId" {
  description = "Subscription id"
  type        = string
}

variable "resourceGroupName" {
  description = "The name of the resource group in which to create the OpenAI resource"
  type        = string
}

variable "openAIResourceName" {
  description = "The name of the OpenAI resource"
  type        = string
}

variable "openAIResourceLocation" {
  description = "Location for the OpenAI resource"
  type        = string
  default     = ""
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

variable "openAIDeploymentName" {
  description = "Deployment Name"
  type        = string
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
  default     = 50
}

data "azurerm_subscription" "current" {}

data "azurerm_resource_group" "rg" {
  name = var.resourceGroupName
}

locals {
  resource_suffix = substr(md5("${data.azurerm_subscription.current.subscription_id}${data.azurerm_resource_group.rg.id}"), 0, 8)
}

resource "azurerm_cognitive_account" "openai" {
  name                = "${var.openAIResourceName }-${local.resource_suffix}"
  location            = (var.openAIResourceLocation == "") ? data.azurerm_resource_group.rg.location : var.openAIResourceLocation
  resource_group_name = var.resourceGroupName
  kind                = "OpenAI"
  sku_name            = var.openAISku
}

resource "azurerm_cognitive_deployment" "openai_deployment" {
  name                 = var.openAIDeploymentName
  cognitive_account_id = azurerm_cognitive_account.openai.id

  model {
    format  = "OpenAI"
    name    = var.openAIModelName
    version = var.openAIModelVersion
  }

  sku {
    name     = "ProvisionedManaged"
    capacity = var.openAIModelCapacity
  }
}