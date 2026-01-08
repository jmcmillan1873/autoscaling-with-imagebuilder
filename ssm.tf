# Create an SSM parameter for storing the AMI ID of an image built from Image Builder. 
# This is created in terraform to ensure the parameter exists when the Imagebuilder distribution
# attempts to update it. On an ongoing basis, it will be managed by EC2 Image Builder, so we should
# Include a lifecycle policy that ignores changes to the value. 
resource "aws_ssm_parameter" "custom_built_custom_id" {
  name        = "/imagebuilder/${var.project}/custom_id"
  description = "SSM Parameter for storing the AMI ID of the image built from Image Builder"
  type        = "String"
  data_type   = "aws:ec2:image"
  value       = data.aws_ssm_parameter.al2023.value
  lifecycle {
    ignore_changes = [
      value
    ]
  }
}
