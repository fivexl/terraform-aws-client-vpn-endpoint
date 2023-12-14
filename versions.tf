terraform {
  required_version = ">= 0.15"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.20.1"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 3.2.0"
    }
  }
}
