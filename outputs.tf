################################################################################
# Terraform Outputs
################################################################################
# This file defines output values that are displayed after terraform apply
# and can be referenced by other Terraform configurations or automation scripts.
# Outputs provide visibility into key resource identifiers and configurations.
################################################################################

################################################################################
# VPC and Networking Outputs
################################################################################

output "vpc_id" {
  description = "ID of the VPC created for this infrastructure"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs where compute resources are deployed"
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "List of public subnet IDs (contains NAT Gateway)"
  value       = module.vpc.public_subnets
}

output "nat_gateway_ips" {
  description = "Public IP addresses of NAT Gateway(s) for outbound internet access"
  value       = module.vpc.nat_public_ips
}

################################################################################
# EC2 Auto Scaling Outputs
################################################################################

output "launch_template_id" {
  description = "ID of the Launch Template used by Auto Scaling Group"
  value       = aws_launch_template.custom_lt.id
}

output "launch_template_latest_version" {
  description = "Latest version number of the Launch Template"
  value       = aws_launch_template.custom_lt.latest_version
}

output "autoscaling_group_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.custom_asg.name
}

output "autoscaling_group_arn" {
  description = "ARN of the Auto Scaling Group"
  value       = aws_autoscaling_group.custom_asg.arn
}

################################################################################
# Image Builder Outputs
################################################################################

output "image_pipeline_arn" {
  description = "ARN of the Image Builder pipeline for manual triggering"
  value       = aws_imagebuilder_image_pipeline.pipeline.arn
}

output "image_recipe_arn" {
  description = "ARN of the Image Builder recipe"
  value       = aws_imagebuilder_image_recipe.custom_recipe.arn
}

output "imagebuilder_components" {
  description = "Map of Image Builder component names to ARNs"
  value = {
    os_tooling     = aws_imagebuilder_component.os_tooling.arn
    custom_scripts = aws_imagebuilder_component.custom_scripts.arn
  }
}

output "distribution_configuration_arn" {
  description = "ARN of the Image Builder distribution configuration"
  value       = aws_imagebuilder_distribution_configuration.dist.arn
}

output "eventbridge_rule_name" {
  description = "Name of the EventBridge rule for Image Builder completion (for disabling during isolated testing)"
  value       = aws_cloudwatch_event_rule.imagebuilder_completed.name
}

################################################################################
# Lambda Function Outputs
################################################################################

output "ltupdater_lambda_arn" {
  description = "ARN of Launch Template updater Lambda function"
  value       = aws_lambda_function.update_launch_template.arn
}

output "amicleaner_lambda_arn" {
  description = "ARN of AMI cleaner Lambda function"
  value       = aws_lambda_function.ami_retention.arn
}

################################################################################
# IAM Role Outputs
################################################################################

output "imagebuilder_role_arn" {
  description = "ARN of IAM role used by Image Builder instances"
  value       = aws_iam_role.imagebuilder_role.arn
}

output "ec2_instance_profile_arn" {
  description = "ARN of IAM instance profile for EC2 instances"
  value       = aws_iam_instance_profile.scanbox.arn
}

################################################################################
# Parameter Store Outputs
################################################################################

output "ami_parameter_name" {
  description = "SSM Parameter Store path containing current AMI ID"
  value       = aws_ssm_parameter.custom_built_custom_id.name
}

output "current_ami_id" {
  description = "Current AMI ID stored in Parameter Store (may be outdated after builds)"
  value       = aws_ssm_parameter.custom_built_custom_id.value
  sensitive   = false
}

################################################################################
# Security Group Outputs
################################################################################

output "instance_security_group_id" {
  description = "Security group ID for EC2 instances and Image Builder"
  value       = aws_security_group.MyExampleSG.id
}

output "lambda_security_group_id" {
  description = "Security group ID for Lambda functions"
  value       = aws_security_group.lambda.id
}

################################################################################
# Configuration Summary Outputs
################################################################################

output "deployment_region" {
  description = "AWS region where resources are deployed"
  value       = var.region
}

output "project_name" {
  description = "Project identifier used for resource naming"
  value       = var.project
}

output "ami_retention_count" {
  description = "Number of AMIs retained by cleanup Lambda"
  value       = var.ami_retain_count
}

################################################################################
# Quick Reference Commands
################################################################################

output "useful_commands" {
  description = "Helpful AWS CLI commands for managing this infrastructure"
  value = <<-EOT
    # View current AMI ID
    aws ssm get-parameter --name ${aws_ssm_parameter.custom_built_custom_id.name} --region ${var.region}
    
    # Manually trigger Image Builder pipeline
    aws imagebuilder start-image-pipeline-execution --image-pipeline-arn ${aws_imagebuilder_image_pipeline.pipeline.arn} --region ${var.region}
    
    # View Image Builder execution history
    aws imagebuilder list-image-pipeline-images --image-pipeline-arn ${aws_imagebuilder_image_pipeline.pipeline.arn} --region ${var.region}
    
    # Update Auto Scaling Group desired capacity
    aws autoscaling set-desired-capacity --auto-scaling-group-name ${aws_autoscaling_group.custom_asg.name} --desired-capacity 1 --region ${var.region}
    
    # View Lambda function logs (ltupdater)
    aws logs tail /aws/lambda/${aws_lambda_function.update_launch_template.function_name} --follow --region ${var.region}
    
    # View Lambda function logs (amicleaner)
    aws logs tail /aws/lambda/${aws_lambda_function.ami_retention.function_name} --follow --region ${var.region}
    
    # List AMIs created by Image Builder
    aws ec2 describe-images --owners self --filters "Name=tag:ManagedBy,Values=AWSImageBuilder" "Name=tag:Project,Values=${var.project}" --region ${var.region}
  EOT
}

################################################################################
# Notes on Using Outputs
################################################################################
# 
# Outputs can be used in several ways:
#
# 1. DISPLAY AFTER APPLY
#    Outputs are automatically displayed after terraform apply
#
# 2. QUERY SPECIFIC OUTPUT
#    terraform output <output_name>
#    Example: terraform output vpc_id
#
# 3. JSON FORMAT (for scripting)
#    terraform output -json
#    terraform output -json vpc_id | jq -r
#
# 4. REFERENCE IN OTHER TERRAFORM CONFIGURATIONS
#    data "terraform_remote_state" "infra" {
#      backend = "s3"
#      config = { bucket = "my-terraform-state" }
#    }
#    value = data.terraform_remote_state.infra.outputs.vpc_id
#
# 5. USE IN CI/CD PIPELINES
#    Export outputs as environment variables for downstream jobs
#
################################################################################
