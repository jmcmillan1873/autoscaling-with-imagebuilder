################################################################################
# Main Terraform Configuration
################################################################################
# This file contains the core Terraform and provider configuration that forms
# the foundation of the infrastructure deployment. It defines version constraints
# and provider settings that apply to all resources in this project.
################################################################################

# Terraform Block
# Defines the minimum Terraform version and required provider plugins
terraform {
  # Require Terraform version 1.11.0 or higher
  # This ensures compatibility with features and syntax used throughout the project
  required_version = ">=1.11.0"
  
  # Specify required providers and their version constraints
  required_providers {
    aws = {
      # Use the official HashiCorp AWS provider
      source  = "hashicorp/aws"
      # Allow any version 6.x (6.0 through 6.999...)
      # The tilde (~>) operator ensures we get bug fixes but not breaking changes
      version = "~>6.0"
    }
  }
}

# AWS Provider Configuration
# Configures authentication and default settings for AWS resources
# Note: AWS credentials are obtained from environment variables, AWS CLI config,
# or IAM roles (depending on execution environment)
provider "aws" {
  # Deploy resources to the region specified in variables.tf
  # This allows for flexible multi-region deployments
  region = var.region
  
  # Apply default tags to ALL AWS resources created by Terraform
  # This ensures consistent tagging for cost allocation, ownership tracking,
  # and resource management across the entire infrastructure
  default_tags {
    tags = var.default_tags
  }
}
