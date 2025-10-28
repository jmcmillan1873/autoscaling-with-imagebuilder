# Dynamic values that are otherwise unchanging
data "aws_caller_identity" "current" {}


#############################################
# Define a trust policy for the Lambda role #
#############################################
data "aws_iam_policy_document" "assume_lambda" {
  statement {
    sid     = "AllowLambdaToAssumeRole"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

#################################################################################################
# Define Permissions policy for lambda function that updates launch template with latest AMI ID #
#################################################################################################
data "aws_iam_policy_document" "lambda_ltupdater_policy" {

  statement {
    sid = "AllowLambdaCloudwatchLogging"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = ["*"]
  }

  statement {
    sid = "GrantSSMAccess"
    actions = [
      "ssm:GetParameter",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribeLaunchTemplateVersions",
      "ec2:ModifyLaunchTemplate",
      "ec2:CreateLaunchTemplateVersion"
    ]

    resources = ["*"]
  }
}

#######################################################
# Create a zip file for the ltupdater lambda function #
#######################################################
data "archive_file" "ltupdater" {
  type        = "zip"
  source_file = "${path.module}/files/ltupdater_lambda_function.py"
  output_path = "${path.module}/files/ltupdater_lambda.zip"
}

##################################################
# Allow the instance to assume the scanning role #
##################################################
# EC2 Assume Role Policy
data "aws_iam_policy_document" "assume_ec2" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com", "imagebuilder.amazonaws.com"]
    }
  }
}

###############################################################################
# Define the resource for discovering the latest AMI id for Amazon Linux 2023 #
###############################################################################
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-arm64"
}

########################################
# Define reusalbe managed IAM policies #
########################################
data "aws_iam_policy" "ssm_core" {
  name = "AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy" "lambdavpc" {
  name = "AWSLambdaVPCAccessExecutionRole"
}

data "aws_iam_policy" "ImageBuilderLifeCycle" {
  name = "EC2ImageBuilderLifecycleExecutionPolicy"
}

##########################################
# Define Imagebuilder permissions policy #
##########################################
data "aws_iam_policy_document" "imagebuilder_permissions" {
  statement {
    sid = "AllowSSM"
    actions = [
      "ssm:UpdateInstanceInformation",
      "ssm:SendCommand",
      "ssm:ListCommandInvocations",
      "ssm:GetCommandInvocation"
    ]
    resources = ["*"]
  }

  statement {
    sid = "AllowEBSAMI"
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
    resources = ["*"]
  }

  statement {
    sid = "AllowImageBuilder"
    actions = [
      "imagebuilder:GetImagePipeline",
      "imagebuilder:ListImagePipelines",
      "imagebuilder:GetImageRecipe",
      "imagebuilder:ListImageRecipes",
      "imagebuilder:TagResource",
      "imagebuilder:UnTagResource",
      "imagebuilder:GetComponent"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AllowKMSToGenerateAndDecryptKey"
    effect = "Allow"
    actions = [
      "kms:GenerateDataKey*",
      "kms:Decrypt*"
    ]
    resources = ["arn:aws:kms:${var.region}:${local.account_id}:key/*"]
  }

}

# Create a machine image to see parameter store with. 
# This is an example of how to get the latest AMI ID for Amazon Linux 2023 ARM64 - for use with Graviton based instances. 
# This matches the architecture types we've stipulated in variables.tf for the images we're building. 
data "aws_ami" "al2023" {
  owners      = ["amazon"]
  most_recent = true
  filter {
    name   = "name"
    values = ["al2023-ami-*-arm64"]
  }
}
