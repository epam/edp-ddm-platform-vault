provider "aws" {
  region = var.aws_region
}

terraform {
  required_providers {
    keycloak = {
      source  = "mrparkers/keycloak"
      version = "=4.3.1"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "=6.0.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "=4.0.5"
    }
    null = {
      source  = "hashicorp/null"
      version = "=3.2.2"
    }
    external = {
      source  = "hashicorp/external"
      version = "=2.3.2"
    }
    http = {
      source  = "hashicorp/http"
      version = "=3.4.0"
    }
  }
  required_version = ">= 0.12"
}

