################################################################################
# Systems Manager Parameter Store Configuration
################################################################################
# This file manages the SSM Parameter that stores the current AMI ID.
# The parameter serves as the single source of truth for the latest custom AMI,
# enabling dynamic AMI reference across Launch Templates and Lambda functions.
#
# Workflow:
# 1. Terraform creates the parameter with the base AMI as initial value
# 2. Image Builder updates the parameter when builds complete successfully
# 3. Lambda function reads the parameter to update Launch Templates
# 4. Launch Template references the parameter for instance launches
#
# The lifecycle policy ensures Terraform doesn't overwrite Image Builder updates.
################################################################################

# SSM Parameter for Custom AMI ID
# This parameter stores the ID of the latest custom-built AMI from Image Builder
resource "aws_ssm_parameter" "custom_built_custom_id" {
  # Hierarchical parameter naming following AWS best practices
  # Format: /imagebuilder/{project}/custom_id
  # This allows multiple projects to coexist and organized parameter browsing
  name = "/imagebuilder/${var.project}/custom_id"
  
  # Human-readable description visible in AWS Console
  # Helps operators understand the parameter's purpose
  description = "SSM Parameter for storing the AMI ID of the image built from Image Builder"
  
  # Parameter type: String
  # Standard type for storing text values like AMI IDs
  type = "String"
  
  # Data type: aws:ec2:image
  # Special AWS data type that validates the value is a valid AMI ID (ami-xxxxxxxx)
  # Provides type safety and enables AWS Console to display AMI details
  # Documentation: https://docs.aws.amazon.com/systems-manager/latest/userguide/parameter-store-ec2-aliases.html
  data_type = "aws:ec2:image"
  
  # Initial value: Latest Amazon Linux 2023 AMI ID
  # This value is used until the first Image Builder pipeline execution completes
  # After that, Image Builder automatically updates this parameter with new AMI IDs
  # The base AMI ID comes from the data source in data.tf
  value = data.aws_ssm_parameter.al2023.value
  
  # Lifecycle policy: Ignore changes to the value attribute
  # CRITICAL: This prevents Terraform from reverting Image Builder's updates
  # 
  # Why this is necessary:
  # 1. Terraform creates the parameter on first apply
  # 2. Image Builder Distribution Config updates the parameter when builds complete
  # 3. Without this lifecycle rule, subsequent terraform applies would revert
  #    the parameter back to the base AMI, breaking the automation
  # 4. With this rule, Terraform creates but doesn't manage the value after creation
  #
  # Trade-offs:
  # - Pro: Allows Image Builder to manage the parameter value
  # - Pro: Terraform won't show the parameter as changed on every plan
  # - Con: terraform plan won't detect manual parameter changes
  # - Con: Requires terraform taint to reset the parameter value
  lifecycle {
    ignore_changes = [
      value  # Ignore runtime changes to the AMI ID value
    ]
  }
}

# Parameter Store Benefits:
# - Versioning: SSM automatically versions parameter changes
# - Encryption: Can be encrypted with KMS (upgrade from String to SecureString)
# - Change tracking: CloudWatch Events can monitor parameter changes
# - Cross-service integration: Multiple services can read the same parameter
# - Hierarchical organization: Parameters can be grouped by path
# - IAM control: Fine-grained access control via IAM policies

# Alternative approaches considered:
# 1. EventBridge event payload: Less reliable, event retention limited
# 2. S3 file: More complex, requires additional permissions
# 3. DynamoDB table: Overkill for single value, adds complexity
# 4. Hardcoded in Terraform: Defeats automation purpose
# Parameter Store is the simplest and most reliable option
