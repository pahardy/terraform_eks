terraform {
  required_version = ">=1.3"
  required_providers {
    aws = {
      version = ">=5.0"
    }

    tls = {
      source = "hashicorp/tls"
      version = "~>4.0.4"
    }

    random = {
      source = "hashicorp/random"
      version = "~>3.5.1"
    }

    cloudinit = {
      source = "hashicorp/cloudinit"
      version = "~>2.3.2"
    }
  }
}

provider "aws" {
  region = var.aws_region
}