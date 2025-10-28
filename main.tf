# Define providers used in the code.

terraform {
  required_version = ">=1.11.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.13.0"
    }
  }
}

# Local account provider
provider "aws" {
  region = var.region
  default_tags {
    tags = var.default_tags
  }
}
