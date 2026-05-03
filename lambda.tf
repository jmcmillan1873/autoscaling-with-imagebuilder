################################################################################
# Lambda Functions for Automated Infrastructure Management
################################################################################
# This file defines the AMI cleaner Lambda function that automates AMI lifecycle
# management by deleting old AMIs and snapshots to control storage costs.
#
# The function runs in VPC private subnets for secure AWS API access and
# enhanced security monitoring via VPC Flow Logs and GuardDuty integration.
################################################################################

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

  # VPC Configuration - same as amicleaner Lambda
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
