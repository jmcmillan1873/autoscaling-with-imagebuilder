################################################################################
# Data Sources and IAM Policy Documents
################################################################################
# This file contains:
# 1. Data sources that query AWS for external information
# 2. IAM policy documents defining permissions and trust relationships
# 3. Archive resources for Lambda deployment packages
#
# Data sources allow Terraform to reference existing AWS resources or
# AWS-managed information without creating new resources. IAM policy documents
# define who can do what with which AWS resources.
################################################################################

################################################################################
# AWS Account Information
################################################################################

# Current AWS Account Identity
# Retrieves information about the AWS account and caller making Terraform requests
# This data source has no arguments - it automatically uses the provider credentials
data "aws_caller_identity" "current" {}

# Available attributes:
# - account_id: The AWS account ID (used in locals.tf)
# - arn: ARN of the calling identity
# - user_id: Unique ID of the calling entity
# This information is used for constructing ARNs and multi-account setups


################################################################################
# IAM Trust Policies (AssumeRole Policies)
################################################################################
# Trust policies define which AWS services or principals can assume an IAM role.
# These are attached to roles as assume_role_policy attributes.
################################################################################

# Lambda Service Trust Policy
# Allows AWS Lambda service to assume roles for function execution
data "aws_iam_policy_document" "assume_lambda" {
  statement {
    # Statement identifier for tracking and documentation
    sid = "AllowLambdaToAssumeRole"
    
    # sts:AssumeRole action allows a principal to assume this role
    actions = ["sts:AssumeRole"]
    
    # Define who can assume this role
    principals {
      # Service principal = AWS service (not IAM user or role)
      type = "Service"
      
      # lambda.amazonaws.com = AWS Lambda service
      # This allows Lambda functions to use this role for execution
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# EC2 and Image Builder Service Trust Policy
# Allows both EC2 instances and Image Builder to assume roles
data "aws_iam_policy_document" "assume_ec2" {
  statement {
    effect = "Allow"
    
    # sts:AssumeRole action for role assumption
    actions = ["sts:AssumeRole"]
    
    principals {
      type = "Service"
      
      # Two service principals:
      # - ec2.amazonaws.com: For EC2 instance launch
      # - imagebuilder.amazonaws.com: For Image Builder pipeline execution
      # Both need access since Image Builder launches temporary EC2 instances
      identifiers = ["ec2.amazonaws.com", "imagebuilder.amazonaws.com"]
    }
  }
}


################################################################################
# Lambda Function IAM Permission Policies
################################################################################
# These policy documents define what actions Lambda functions can perform.
# They are attached to Lambda execution roles as inline or managed policies.
################################################################################

# Launch Template Updater Lambda Permissions
# Grants permissions for updating Launch Templates and reading from Parameter Store
data "aws_iam_policy_document" "lambda_ltupdater_policy" {

  # CloudWatch Logs Permissions
  # Required for Lambda function logging and troubleshooting
  statement {
    sid = "AllowLambdaCloudwatchLogging"
    
    # Actions needed for CloudWatch Logs integration:
    # - CreateLogGroup: Create log group on first execution
    # - CreateLogStream: Create log stream for each invocation
    # - PutLogEvents: Write log messages to CloudWatch
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    # Resource "*" is AWS best practice for Lambda logging
    # Logs are restricted by function name in the log group path
    resources = ["*"]
  }

  # Systems Manager and EC2 Permissions
  # Required for reading AMI ID and updating Launch Templates
  statement {
    sid = "GrantSSMAccess"
    
    # Required actions:
    # - ssm:GetParameter: Read AMI ID from Parameter Store
    # - ec2:DescribeLaunchTemplates: Query Launch Template details
    # - ec2:DescribeLaunchTemplateVersions: Get version information
    # - ec2:ModifyLaunchTemplate: Set default version
    # - ec2:CreateLaunchTemplateVersion: Create new version with updated AMI
    actions = [
      "ssm:GetParameter",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribeLaunchTemplateVersions",
      "ec2:ModifyLaunchTemplate",
      "ec2:CreateLaunchTemplateVersion"
    ]

    # Resource "*" provides flexibility for multi-resource access
    # In production, consider restricting to specific resource ARNs:
    # - arn:aws:ssm:${var.region}:${local.account_id}:parameter/imagebuilder/*
    # - arn:aws:ec2:${var.region}:${local.account_id}:launch-template/*
    resources = ["*"]
  }
}

# AMI Cleaner Lambda Permissions
# Grants permissions for querying and deleting AMIs and snapshots
data "aws_iam_policy_document" "lambda_amicleaner_policy" {

  # EC2 Describe Permissions
  # Required for querying AMIs, snapshots, and Launch Templates
  statement {
    sid = "DescribeEC2Artifacts"
    
    # Read-only describe actions:
    # - DescribeImages: Query AMIs by tags and filters
    # - DescribeSnapshots: Identify snapshots associated with AMIs
    # - DescribeLaunchTemplates: Check Launch Template details
    # - DescribeLaunchTemplateVersions: Identify AMIs in use
    actions = [
      "ec2:DescribeImages",
      "ec2:DescribeSnapshots",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribeLaunchTemplateVersions"
    ]
    
    effect = "Allow"
    
    # Describe actions require resource "*" per AWS API requirements
    resources = ["*"]
  }

  # EC2 Delete Permissions
  # Required for cleaning up old AMIs and snapshots
  statement {
    sid = "DeleteOldAMIsAndSnapshots"
    
    # Destructive actions (use with caution):
    # - DeregisterImage: Delete (deregister) AMIs
    # - DeleteSnapshot: Remove EBS snapshots
    # The Lambda function logic ensures only old, unused AMIs are deleted
    actions = [
      "ec2:DeregisterImage",
      "ec2:DeleteSnapshot"
    ]
    
    effect = "Allow"
    
    # Resource "*" required - deletion actions apply to resources identified at runtime
    # Safety is enforced by Lambda function logic (tag filtering, retention count)
    # and DRY_RUN environment variable (default: true)
    resources = ["*"]
  }
}


################################################################################
# Image Builder IAM Permissions
################################################################################
# This policy document defines permissions for Image Builder instances during
# the AMI creation process. Includes permissions for SSM communication, AMI
# creation, tagging, and encryption.
################################################################################

# Image Builder Comprehensive Permissions Policy
data "aws_iam_policy_document" "imagebuilder_permissions" {
  
  # Systems Manager Permissions
  # Required for Image Builder component execution and status reporting
  statement {
    sid = "AllowSSM"
    
    # SSM actions for component execution:
    # - UpdateInstanceInformation: Register instance with SSM
    # - SendCommand: Execute build components on instance
    # - ListCommandInvocations: Monitor component execution status
    # - GetCommandInvocation: Retrieve component execution results
    actions = [
      "ssm:UpdateInstanceInformation",
      "ssm:SendCommand",
      "ssm:ListCommandInvocations",
      "ssm:GetCommandInvocation"
    ]
    
    # Resource "*" required for SSM command execution
    resources = ["*"]
  }

  # EC2 AMI Management Permissions
  # Required for creating, modifying, and managing AMIs and snapshots
  statement {
    sid = "AllowEBSAMI"
    
    # AMI and snapshot management actions:
    # - CreateImage: Create AMI from build instance
    # - RegisterImage: Register custom AMIs
    # - DeregisterImage: Clean up failed builds
    # - ModifyImageAttribute: Set AMI permissions and properties
    # - CopyImage: Support multi-region distribution (if configured)
    # - CreateTags: Apply tags to AMIs and snapshots
    # - Describe*: Query EC2 resources (wildcard for all describe actions)
    # - DeleteSnapshot: Clean up snapshots from failed builds
    # - tag:GetResources: Query resources by tags
    actions = [
      "ec2:CreateImage",
      "ec2:RegisterImage",
      "ec2:DeregisterImage",
      "ec2:ModifyImageAttribute",
      "ec2:CopyImage",
      "ec2:CreateTags",
      "ec2:Describe*",
      "ec2:DeleteSnapshot",
      "tag:GetResources"
    ]
    
    # Resource "*" allows Image Builder to manage all AMI-related resources
    resources = ["*"]
  }

  # Image Builder Service Permissions
  # Required for pipeline orchestration and component management
  statement {
    sid = "AllowImageBuilder"
    
    # Image Builder API actions:
    # - GetImagePipeline: Query pipeline configuration
    # - ListImagePipelines: Enumerate available pipelines
    # - GetImageRecipe: Retrieve recipe details
    # - ListImageRecipes: Enumerate available recipes
    # - TagResource/UnTagResource: Manage resource tags
    # - GetComponent: Retrieve component definitions
    actions = [
      "imagebuilder:GetImagePipeline",
      "imagebuilder:ListImagePipelines",
      "imagebuilder:GetImageRecipe",
      "imagebuilder:ListImageRecipes",
      "imagebuilder:TagResource",
      "imagebuilder:UnTagResource",
      "imagebuilder:GetComponent"
    ]
    
    # Resource "*" allows access to all Image Builder resources in the account
    resources = ["*"]
  }

  # KMS Encryption Permissions
  # Required for creating encrypted EBS volumes and AMIs
  statement {
    sid    = "AllowKMSToGenerateAndDecryptKey"
    effect = "Allow"
    
    # KMS actions for encryption:
    # - GenerateDataKey*: Generate data keys for EBS encryption
    # - Decrypt*: Decrypt data keys when creating AMIs
    # These permissions support EBS encryption at rest
    actions = [
      "kms:GenerateDataKey*",
      "kms:Decrypt*"
    ]
    
    # Scope to KMS keys in current region and account
    # Wildcard allows Image Builder to work with any KMS key
    # For production, consider restricting to specific KMS key ARNs
    resources = ["arn:aws:kms:${var.region}:${local.account_id}:key/*"]
  }
}


################################################################################
# AWS-Managed IAM Policies
################################################################################
# These data sources reference AWS-managed IAM policies that are maintained
# by AWS. Using managed policies reduces maintenance burden and ensures
# policies stay current with AWS best practices.
################################################################################

# Amazon SSM Managed Instance Core Policy
# AWS-managed policy providing base SSM functionality for EC2 instances
data "aws_iam_policy" "ssm_core" {
  # Policy ARN: arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
  # Grants permissions for:
  # - SSM Agent communication with SSM service
  # - Instance registration and heartbeat
  # - Command execution and status reporting
  # - Session Manager access (if enabled)
  # - CloudWatch Logs integration for SSM
  name = "AmazonSSMManagedInstanceCore"
}

# AWS Lambda VPC Access Execution Role
# AWS-managed policy for Lambda functions running in VPCs
data "aws_iam_policy" "lambdavpc" {
  # Policy ARN: arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole
  # Grants permissions for:
  # - Creating/deleting network interfaces (ENIs) in VPC
  # - Describing network interfaces, security groups, subnets
  # - CloudWatch Logs creation and writing
  # Required for any Lambda function with vpc_config block
  name = "AWSLambdaVPCAccessExecutionRole"
}

# EC2 Image Builder Lifecycle Execution Policy  
# AWS-managed policy for Image Builder lifecycle operations
data "aws_iam_policy" "ImageBuilderLifeCycle" {
  # Policy ARN: arn:aws:iam::aws:policy/EC2ImageBuilderLifecycleExecutionPolicy
  # Provides permissions for Image Builder lifecycle hooks and automation
  # Note: This policy is referenced but not currently attached in this configuration
  # Included for potential future use with lifecycle policies
  name = "EC2ImageBuilderLifecycleExecutionPolicy"
}


################################################################################
# Amazon Linux 2023 AMI Discovery
################################################################################
# Retrieves the latest Amazon Linux 2023 AMI ID from AWS-managed Parameter Store.
# AWS maintains these parameters with the most recent AMIs, ensuring we always
# use up-to-date base images without hardcoding AMI IDs.
################################################################################

# Latest Amazon Linux 2023 ARM64 AMI ID
# AWS publishes official AMI IDs to Parameter Store for easy discovery
data "aws_ssm_parameter" "al2023" {
  # AWS-managed parameter path for Amazon Linux 2023 AMIs
  # Format: /aws/service/ami-amazon-linux-latest/{ami-name}
  # 
  # Parameter breakdown:
  # - al2023: Amazon Linux 2023 (latest generation)
  # - ami: Standard Amazon Machine Image
  # - kernel-6.1: Kernel version 6.1 (long-term support)
  # - arm64: ARM64 architecture (for Graviton instances)
  #
  # For x86_64 architecture, change to:
  # /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-arm64"
  
  # This parameter value is used as:
  # 1. Base image for Image Builder recipes (imagebuilder.tf)
  # 2. Initial value for custom AMI parameter (ssm.tf)
  # 3. Launch Template AMI before first Image Builder build
}

# Note: AWS also provides parameters for other distributions:
# - Amazon Linux 2: /aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-arm64-gp2
# - Ubuntu: Available through Canonical's public parameters
# - Windows Server: /aws/service/ami-windows-latest/Windows_Server-{version}


################################################################################
# Lambda Deployment Packages
################################################################################
# These archive_file data sources create ZIP files from Python source code
# for Lambda function deployment. Terraform automatically detects source code
# changes and recreates the ZIP files, triggering Lambda function updates.
################################################################################

# Launch Template Updater Lambda Deployment Package
# Creates ZIP archive from Python source file
data "archive_file" "ltupdater" {
  # Archive type - ZIP format required for Lambda
  type = "zip"
  
  # Source Python file containing the Lambda function code
  # Path is relative to the Terraform module root
  source_file = "${path.module}/files/ltupdater_lambda_function.py"
  
  # Output path for the generated ZIP file
  # This ZIP is uploaded to Lambda during terraform apply
  output_path = "${path.module}/files/ltupdater_lambda.zip"
  
  # Note: output_base64sha256 attribute is used in lambda.tf to detect
  # code changes and trigger Lambda function updates automatically
}

# AMI Cleaner Lambda Deployment Package
# Creates ZIP archive from AMI cleanup Python source file
data "archive_file" "amicleaner" {
  # Archive type - ZIP format for Lambda deployment
  type = "zip"
  
  # Source Python file with AMI cleanup logic
  source_file = "${path.module}/files/amicleaner_lambda_function.py"
  
  # Output ZIP file path
  output_path = "${path.module}/files/amicleaner_lambda.zip"
  
  # Terraform tracks the source file hash to detect changes
  # Any modification to the Python file triggers ZIP recreation
  # and Lambda function redeployment
}
