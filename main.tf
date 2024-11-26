terraform {
  required_version = ">=1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">=5.42.0"
    }
    azurerm = {
      source = "hashicorp/azurerm"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "0.9.1"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subId
}

provider "aws" {
  region                   = "us-east-1"
  shared_config_files      = var.configfile
  shared_credentials_files = var.credentialsfile
}