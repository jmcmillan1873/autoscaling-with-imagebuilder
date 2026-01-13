################################################################################
# Lambda Functions for Automated Infrastructure Management
################################################################################
# This file defines two Lambda functions that automate AMI lifecycle management:
# 1. ltupdater: Updates Launch Template with newly built AMIs
# 2. amicleaner: Performs housekeeping by deleting old AMIs and snapshots
#
# Both functions run in VPC private subnets for secure AWS API access and
# enhanced security monitoring via VPC Flow Logs and GuardDuty integration.
################################################################################

################################################################################
# Launch Template Updater Lambda Function (ltupdater)
################################################################################
# This function is triggered by EventBridge when Image Builder completes a
# successful AMI build. It updates the Launch Template with the new AMI ID,
# ensuring future Auto Scaling Group instances use the latest, patched image.
################################################################################

# IAM Role for Launch Template Updater Lambda
# This role allows Lambda service to assume it and defines what the function can do
resource "aws_iam_role" "lambda-ltupdater" {
  name = "ltupdater-role"
  
  # Trust policy allowing Lambda service to assume this role
  # Defined in data.tf for reusability across multiple Lambda functions
  assume_role_policy = data.aws_iam_policy_document.assume_lambda.json
}

# Custom IAM Policy for Launch Template Updater
# Grants specific permissions needed to update Launch Templates and read from Parameter Store
resource "aws_iam_policy" "ltupdater-lambda_policy" {
  name = "ltupdater-policy"
  
  # Policy document defined in data.tf containing:
  # - CloudWatch Logs permissions (CreateLogGroup, CreateLogStream, PutLogEvents)
  # - SSM Parameter Store read access (GetParameter)
  # - EC2 Launch Template operations (Describe*, Create*, Modify*)
  policy = data.aws_iam_policy_document.lambda_ltupdater_policy.json
}

# Attach Custom Policy to Role
# This grants the Lambda function permissions defined in ltupdater-lambda_policy
resource "aws_iam_role_policy_attachment" "ltupdater-attach" {
  role       = aws_iam_role.lambda-ltupdater.name
  policy_arn = aws_iam_policy.ltupdater-lambda_policy.arn
}

# Attach AWS Managed VPC Execution Policy
# Required for Lambda functions running in VPC - manages ENI creation/deletion
# Grants permissions: CreateNetworkInterface, DescribeNetworkInterfaces, DeleteNetworkInterface
resource "aws_iam_role_policy_attachment" "attach_vpc-ltupdater" {
  role       = aws_iam_role.lambda-ltupdater.name
  policy_arn = data.aws_iam_policy.lambdavpc.arn
}

# Launch Template Updater Lambda Function Definition
# This is the core Lambda function that performs the actual update operations
resource "aws_lambda_function" "update_launch_template" {
  # Function name appears in CloudWatch Logs and AWS Console
  function_name = "ltupdater"
  
  # IAM role ARN - grants function permissions to AWS services
  role = aws_iam_role.lambda-ltupdater.arn
  
  # Handler format: filename.function_name
  # Points to handler() function in ltupdater_lambda_function.py
  handler = "ltupdater_lambda_function.handler"
  
  # Python 3.12 runtime provides latest features and security updates
  runtime = "python3.12"
  
  # ZIP file containing function code (created by data.archive_file in data.tf)
  filename = data.archive_file.ltupdater.output_path
  
  # Timeout of 60 seconds - sufficient for Launch Template update operations
  # Typical execution time: 2-5 seconds for API calls
  timeout = 60
  
  # Source code hash ensures Lambda updates when code changes
  # Terraform compares this hash to detect changes and redeploy if needed
  source_code_hash = data.archive_file.ltupdater.output_base64sha256

  # Environment variables passed to the Lambda function
  # These allow configuration changes without modifying code
  environment {
    variables = {
      # Parameter Store path containing latest AMI ID
      SSM_PARAM_NAME = aws_ssm_parameter.custom_built_custom_id.name
      
      # Launch Template ID to update with new AMI
      LAUNCH_TEMPLATE_ID = aws_launch_template.custom_lt.id
      
      # Instance type to use in new Launch Template versions
      INSTANCE_TYPE = var.instance_type
      
      # Security group to apply to instances
      SECURITY_GROUP_ID = aws_security_group.MyExampleSG.id
      
      # IAM instance profile for EC2 instance permissions
      IAM_INSTANCE_PROFILE = aws_iam_instance_profile.scanbox.name
    }
  }

  # VPC Configuration - runs Lambda in private subnets
  # Benefits:
  # - Enhanced security (no direct internet access)
  # - VPC Flow Logs capture network activity
  # - GuardDuty monitoring for anomalous behavior
  # - Access to VPC-internal resources if needed
  vpc_config {
    # Deploy in all private subnets for high availability
    subnet_ids = module.vpc.private_subnets
    
    # Security group allowing HTTPS outbound for AWS API calls
    security_group_ids = [aws_security_group.lambda.id]
  }
}

# Lambda Permission for EventBridge Invocation
# Grants EventBridge permission to invoke this Lambda function
# Without this, EventBridge rule would be denied access
resource "aws_lambda_permission" "allow_eventbridge" {
  # Unique identifier for this permission statement
  statement_id = "AllowExecutionFromEventBridge"
  
  # The action EventBridge is allowed to perform
  action = "lambda:InvokeFunction"
  
  # The Lambda function to grant permission on
  function_name = aws_lambda_function.update_launch_template.function_name
  
  # AWS service principal allowed to invoke (events.amazonaws.com = EventBridge)
  principal = "events.amazonaws.com"
  
  # Restrict permission to specific EventBridge rule (prevents other rules from invoking)
  source_arn = aws_cloudwatch_event_rule.imagebuilder_completed.arn
}


################################################################################
# AMI Cleaner Lambda Function (amicleaner)
################################################################################
# This function performs automated lifecycle management of AMIs created by
# Image Builder. It deletes old AMIs and associated snapshots to prevent
# accumulation and reduce storage costs, while protecting recent AMIs and
# AMIs referenced by active Launch Template versions.
################################################################################

# AMI Cleaner Lambda Function Definition
resource "aws_lambda_function" "ami_retention" {
  # Function name includes project identifier for easy identification
  function_name = "${var.project}-ami-retention"
  
  # IAM role granting permissions to describe/delete AMIs and snapshots
  role = aws_iam_role.ami_retention_lambda.arn
  
  # Handler format: filename.function_name
  # Points to lambda_handler() function in amicleaner_lambda_function.py
  handler = "amicleaner_lambda_function.lambda_handler"
  
  # Python 3.12 runtime for latest features and security
  runtime = "python3.12"
  
  # ZIP file containing function code
  filename = data.archive_file.amicleaner.output_path
  
  # Timeout of 300 seconds (5 minutes) - deletion operations can take time
  # With many AMIs and snapshots, API calls can accumulate
  # Also allows for pagination of describe_images if many AMIs exist
  timeout = 300
  
  # Source code hash for change detection
  source_code_hash = data.archive_file.amicleaner.output_base64sha256

  # Environment variables configuring retention behavior
  environment {
    variables = {
      # Number of newest AMIs to always keep (as string for env var compatibility)
      RETAIN_COUNT = tostring(var.ami_retain_count)
      
      # Project tag value to filter AMIs (only delete AMIs with this tag)
      PROJECT_TAG_VALUE = var.project
      
      # ManagedBy tag value to filter AMIs (ensures we only delete Image Builder AMIs)
      MANAGED_BY_VALUE = "AWSImageBuilder"
      
      # DRY_RUN mode - when "true", logs actions without actually deleting
      # Set to "false" only after testing to enable actual deletion
      # Default "true" prevents accidental deletions during initial deployment
      DRY_RUN = "true" # flip to false when confident
      
      # Launch Template ID to check for AMI usage
      # Prevents deletion of AMIs referenced by recent LT versions
      LAUNCH_TEMPLATE_ID = aws_launch_template.custom_lt.id
    }
  }

  # VPC Configuration - same benefits as ltupdater Lambda
  vpc_config {
    subnet_ids         = module.vpc.private_subnets
    security_group_ids = [aws_security_group.lambda.id]
  }
}

# Lambda Permission for EventBridge Schedule Invocation
# Allows scheduled EventBridge rule to trigger AMI cleanup daily
resource "aws_lambda_permission" "allow_eventbridge_amicleaner" {
  # Unique identifier for this permission statement
  statement_id = "AllowExecutionFromEventBridgeAmicleanerSchedule"
  
  # The action EventBridge is allowed to perform
  action = "lambda:InvokeFunction"
  
  # The Lambda function to grant permission on
  function_name = aws_lambda_function.ami_retention.function_name
  
  # AWS service principal (EventBridge)
  principal = "events.amazonaws.com"
  
  # Restrict to specific scheduled EventBridge rule
  source_arn = aws_cloudwatch_event_rule.amicleaner_schedule.arn
}
