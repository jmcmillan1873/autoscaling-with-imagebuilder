################################################################################
# Locals - Computed Values
################################################################################
# This file defines local values that are computed at runtime rather than
# being explicitly configured. Local values can reference other resources,
# data sources, or variables to create derived values used throughout the
# configuration.
#
# Benefits of using locals:
# - Avoid hardcoding values (like account IDs) in multiple places
# - Create DRY (Don't Repeat Yourself) code
# - Support multi-account and multi-region deployments
# - Improve maintainability and readability
################################################################################

locals {
  # Current AWS Account ID
  # Dynamically retrieved from the AWS caller identity data source (defined in data.tf)
  # This eliminates the need to hardcode account IDs, making the code portable
  # across different AWS accounts (dev, staging, production, etc.)
  #
  # Usage examples:
  # - Constructing ARNs for IAM policies: arn:aws:kms:${var.region}:${local.account_id}:key/*
  # - Resource tagging with account information
  # - Cross-account access configurations
  # - Conditional logic based on account
  account_id = data.aws_caller_identity.current.account_id
  
  # Additional computed values can be added here as needed, such as:
  # - Common resource name prefixes: "${var.project}-${var.environment}"
  # - Conditional values based on environment or region
  # - Merged tag sets combining multiple tag maps
  # - Derived network CIDR calculations
  # - Timestamp-based values for unique naming
}
