terraform {
  required_version = ">=1.7"
  required_providers {
    aws = {
      version = ">=5.38"
    }
  }
}

provider "aws" {
  region = var.aws_region
}