terraform {
    required_providers {
        azurerm = {
            source = "opentofu/azurerm"
            version = "3.84.0"
        }
    }
}

provider "azurerm" {
  features{}
  
}