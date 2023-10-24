terraform {
  required_version = ">= 0.15"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 3.2.0"
    }
  }
}
