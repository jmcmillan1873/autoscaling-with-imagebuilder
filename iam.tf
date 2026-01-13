################################################################################
# IAM Roles and Policies
################################################################################
# This file implements least-privilege access control for all infrastructure
# components. Each service (EC2, Image Builder, Lambda) has dedicated roles
# with only the minimum permissions required for its specific functions.
#
# IAM Best Practices Applied:
# - Service-specific roles (not shared between different services)
# - Explicit trust policies (AssumeRole) for each service
# - Inline and managed policies for granular permission control
# - Instance profiles for EC2/Image Builder role attachment
################################################################################

################################################################################
# EC2 Instance Role and Profile
################################################################################
# These resources define IAM permissions for EC2 instances launched by the
# Auto Scaling Group. Currently minimal permissions, but can be extended
# based on application requirements (e.g., S3 access, DynamoDB, etc.)
################################################################################

# IAM Role for EC2 Instances
# Allows EC2 instances to assume this role and access AWS services
resource "aws_iam_role" "scanbox" {
  # Role name includes project identifier for easy identification
  name = "${var.project}-scanboxRole"
  
  # Trust policy allowing EC2 service to assume this role
  # Defined in data.tf as assume_ec2 policy document
  # Allows both ec2.amazonaws.com and imagebuilder.amazonaws.com principals
  assume_role_policy = data.aws_iam_policy_document.assume_ec2.json
  
  # Note: This role currently has minimal permissions. Add additional
  # policy attachments based on application requirements:
  # - S3 access for reading/writing data
  # - DynamoDB for application state
  # - Secrets Manager for retrieving credentials
  # - CloudWatch for custom metrics/logs
}

# EC2 Instance Profile
# Instance profiles are AWS constructs that allow EC2 instances to assume IAM roles
# The instance profile is attached to EC2 instances via the launch template
resource "aws_iam_instance_profile" "scanbox" {
  name = "${var.project}-InstanceProfile"
  
  # Link to the IAM role defined above
  role = aws_iam_role.scanbox.name
  
  # Note: Instance profiles can only contain one role, but that role can have
  # multiple policies attached for different permissions
}


################################################################################
# Image Builder Role and Profile
################################################################################
# These resources define IAM permissions for the temporary EC2 instances that
# Image Builder launches during AMI creation. These instances need elevated
# permissions to install software, create AMIs, and update Parameter Store.
################################################################################

# IAM Role for Image Builder Instances
# Used by temporary build instances during AMI creation
resource "aws_iam_role" "imagebuilder_role" {
  name = "${var.project}-imagebuilder-role"
  
  # Trust policy allowing both EC2 and Image Builder services to assume this role
  # EC2: For the actual instance launching
  # ImageBuilder: For orchestration and component execution
  assume_role_policy = data.aws_iam_policy_document.assume_ec2.json
}

# Attach AWS Managed SSM Core Policy
# Required for Image Builder instances to communicate with Systems Manager
# Enables:
# - SSM Agent functionality on build instances
# - Component execution and status reporting
# - Session Manager access for troubleshooting (if needed)
resource "aws_iam_role_policy_attachment" "ssm-imagebuilder" {
  role = aws_iam_role.imagebuilder_role.name
  
  # AWS managed policy providing core SSM functionality
  # Policy ARN: arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
  policy_arn = data.aws_iam_policy.ssm_core.arn
}

# Attach Custom Image Builder Permissions Policy
# Grants permissions specific to AMI creation and distribution
resource "aws_iam_role_policy" "imagebuilder_permissions" {
  name = "ImageBuilderPermissions"
  role = aws_iam_role.imagebuilder_role.id
  
  # Custom policy document defined in data.tf containing permissions for:
  # - SSM: UpdateInstanceInformation, SendCommand (for component execution)
  # - EC2: CreateImage, RegisterImage, CreateTags, Describe* (for AMI creation)
  # - EC2: DeleteSnapshot (for cleanup of failed builds)
  # - ImageBuilder: GetImagePipeline, ListImageRecipes (for pipeline awareness)
  # - KMS: GenerateDataKey*, Decrypt* (for encrypted EBS volumes)
  policy = data.aws_iam_policy_document.imagebuilder_permissions.json
}

# Image Builder Instance Profile
# Allows Image Builder to attach the IAM role to temporary build instances
resource "aws_iam_instance_profile" "imagebuilder" {
  name = "${var.project}-Imagebuilder"
  role = aws_iam_role.imagebuilder_role.name
  
  # This instance profile is referenced in imagebuilder.tf infrastructure configuration
  # Image Builder uses it for all temporary build instances
}


################################################################################
# AMI Cleaner Lambda Role and Policies
################################################################################
# These resources define IAM permissions for the Lambda function that performs
# automated cleanup of old AMIs and snapshots. The role grants permissions to
# query, describe, and delete EC2 images and snapshots.
################################################################################

# IAM Role for AMI Retention Lambda Function
resource "aws_iam_role" "ami_retention_lambda" {
  name = "AMI-retention-lambda-role"
  
  # Descriptive information for AWS Console and documentation
  description = "Lambda Function to handle lifecycle of AMI's created by Image Builder."
  
  # Trust policy allowing Lambda service to assume this role
  # Defined in data.tf as assume_lambda policy document
  assume_role_policy = data.aws_iam_policy_document.assume_lambda.json
}

# Custom IAM Policy for AMI Cleaner Lambda
# Defines specific permissions needed for AMI and snapshot lifecycle management
resource "aws_iam_policy" "ami_cleaner_policy" {
  name = "ami-cleaner-policy"
  
  # Policy document defined in data.tf containing permissions for:
  # - ec2:DescribeImages (query AMIs by tags)
  # - ec2:DescribeSnapshots (identify snapshots to delete)
  # - ec2:DescribeLaunchTemplates (check for AMI usage)
  # - ec2:DescribeLaunchTemplateVersions (protect in-use AMIs)
  # - ec2:DeregisterImage (delete old AMIs)
  # - ec2:DeleteSnapshot (remove associated snapshots)
  # - logs:* (CloudWatch Logs for function output - added via VPC policy)
  policy = data.aws_iam_policy_document.lambda_amicleaner_policy.json
}

# Attach AMI Cleaner Policy to Lambda Role
resource "aws_iam_role_policy_attachment" "amicleaner-attach" {
  role       = aws_iam_role.ami_retention_lambda.name
  policy_arn = aws_iam_policy.ami_cleaner_policy.arn
}

# Attach AWS Managed VPC Execution Policy to AMI Cleaner Lambda
# Required for Lambda functions running in VPC - manages ENI lifecycle
resource "aws_iam_role_policy_attachment" "attach_vpc-amicleaner" {
  role = aws_iam_role.ami_retention_lambda.name
  
  # AWS managed policy: AWSLambdaVPCAccessExecutionRole
  # Grants permissions for ENI management and CloudWatch Logs
  policy_arn = data.aws_iam_policy.lambdavpc.arn
}
