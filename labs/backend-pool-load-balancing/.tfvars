subscriptionId = ""
resourceGroupName = "apim-tf-rg"
apimResourceName = "tfapim"
apimSku = "Basicv2"
openAIConfig = [ {"name": "openai1", "location": "uksouth", "priority": 1, "weight": 80}, {"name": "openai2", "location": "swedencentral", "priority": 1, "weight": 10}, {"name": "openai3", "location": "francecentral", "priority": 1, "weight": 10} ] 
openAISku = "S0"
openAIModelName = "gpt-35-turbo"
openAIModelVersion = "0613"
openAIDeploymentName = "gpt-35-turbo"
openAIModelCapacity = 2
openAIAPISpecURL = "https://raw.githubusercontent.com/Azure/azure-rest-api-specs/main/specification/cognitiveservices/data-plane/AzureOpenAI/inference/stable/2024-02-01/inference.json"
openAIBackendPoolName = "openai-backend-pool"
mockBackendPoolName = "mock-backend-pool"
mockWebApps = [ {"name": "openaimock1", "endpoint": "https://openaimock1.azurewebsites.net", "priority": 1, "weight": 80}, {"name": "openaimock2", "endpoint": "https://openaimock2.azurewebsites.net", "priority": 1, "weight": 20} ]