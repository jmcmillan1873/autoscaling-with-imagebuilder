################################################################################
# Input Variables
################################################################################
# This file defines all configurable parameters for the infrastructure.
# Variables can be overridden via terraform.tfvars, command-line flags,
# or environment variables (TF_VAR_name). Default values are provided
# for quick deployment but should be customized for production use.
################################################################################

# AMI Retention Configuration
# Controls how many AMIs are preserved by the AMI cleaner Lambda function
variable "ami_retain_count" {
  description = <<-EOT
    Number of ImageBuilder-created AMIs to retain before deletion.
    The amicleaner Lambda function preserves the newest N AMIs and
    deletes older ones. This prevents AMI accumulation and reduces storage costs.
    Recommended: 5-10 for development, 10-20 for production environments.
  EOT
  type        = number
  default     = 5
  
  # Validation ensures a sensible minimum value
  validation {
    condition     = var.ami_retain_count >= 1
    error_message = "AMI retain count must be at least 1 to preserve the latest AMI."
  }
}

# AWS Region Configuration
# Specifies where infrastructure resources will be deployed
variable "region" {
  description = <<-EOT
    AWS region for resource deployment. Choose a region close to your users
    or that meets compliance requirements. Ensure the region supports all
    required services (EC2 Image Builder, Graviton instances, etc.).
    Common options: us-east-1, us-west-2, eu-west-1, ap-southeast-1
  EOT
  type        = string
  default     = "eu-west-1"
}

# Project Identifier
# Used for resource naming and tagging throughout the infrastructure
variable "project" {
  description = <<-EOT
    Project identifier used for naming resources and tagging.
    This value is used as a prefix for resources like VPCs, security groups,
    launch templates, and appears in resource tags for cost allocation.
    Should be unique within your AWS account to avoid naming conflicts.
    Constraints: alphanumeric and hyphens only, max 20 characters.
  EOT
  type        = string
  default     = "MyExampleProject"
  
  # Validation ensures the project name meets AWS naming requirements
  validation {
    condition     = can(regex("^[a-zA-Z0-9-]+$", var.project)) && length(var.project) <= 20
    error_message = "Project name must be alphanumeric with hyphens only, max 20 characters."
  }
}

# EC2 Instance Type
# Defines the instance type for Auto Scaling Group instances
variable "instance_type" {
  description = <<-EOT
    EC2 instance type for Auto Scaling Group instances.
    Graviton-based instances (t4g family) offer better price-performance.
    For ARM64 compatibility, use t4g/c6g/m6g families.
    For x86 compatibility, change to t3/c5/m5 families and update the
    AMI architecture filter in data sources from 'arm64' to 'x86_64'.
    Common options: t4g.micro (testing), t4g.small (light workloads),
    t4g.medium (moderate workloads), t4g.large (heavier workloads)
  EOT
  type        = string
  default     = "t4g.small"
}

# Image Builder Instance Types
# Specifies instance types for building AMIs
variable "build_instance_types" {
  description = <<-EOT
    List of EC2 instance types for Image Builder to use during AMI creation.
    Multiple types provide flexibility - Image Builder selects based on availability.
    Larger instances reduce build time but increase costs. Consider CPU-intensive
    builds (c6g family) vs. general purpose (t4g family) based on your components.
    Must be ARM64-compatible if using Amazon Linux 2023 ARM64 as the base image.
    Build typically takes 15-30 minutes on t4g.small, 10-20 minutes on t4g.medium.
  EOT
  type        = list(string)
  default     = ["t4g.small", "t4g.medium", "t4g.large", "t4g.2xlarge"]
  
  # Validation ensures at least one instance type is specified
  validation {
    condition     = length(var.build_instance_types) > 0
    error_message = "At least one build instance type must be specified."
  }
}

# Default Resource Tags
# Applied to all resources via the provider's default_tags configuration
variable "default_tags" {
  description = <<-EOT
    Standard tags applied to ALL resources created by Terraform.
    These tags enable cost allocation, ownership tracking, environment
    segregation, and resource management. Tags are automatically applied
    through the AWS provider's default_tags configuration.
    
    Recommended tags:
    - Owner: Team or individual responsible for the resources
    - Project: Project or application name for cost allocation
    - Environment: Development, Staging, Production, etc.
    - CostCenter: Department or cost center for billing
    - ManagedBy: Should be 'Terraform' or similar automation tool
    
    Additional tags can be added without code changes.
  EOT
  type        = map(string)
  default = {
    Owner       = "MeMyselfAndI"
    Project     = "MyExampleProject"
    Environment = "Example"
  }
}
