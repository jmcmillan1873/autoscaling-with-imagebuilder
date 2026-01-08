# IAM Role for EC2 Instance
resource "aws_iam_role" "scanbox" {
  name               = "${var.project}-scanboxRole"
  assume_role_policy = data.aws_iam_policy_document.assume_ec2.json
}

resource "aws_iam_instance_profile" "scanbox" {
  name = "${var.project}-InstanceProfile"
  role = aws_iam_role.scanbox.name
}

# IAM role for Image Builder
resource "aws_iam_role" "imagebuilder_role" {
  name               = "${var.project}-imagebuilder-role"
  assume_role_policy = data.aws_iam_policy_document.assume_ec2.json
}

# Attach SSM core to imagebuilder role
resource "aws_iam_role_policy_attachment" "ssm-imagebuilder" {
  role       = aws_iam_role.imagebuilder_role.name
  policy_arn = data.aws_iam_policy.ssm_core.arn
}

# Attach permissions policy to imagebuilder role
resource "aws_iam_role_policy" "imagebuilder_permissions" {
  name   = "ImageBuilderPermissions"
  role   = aws_iam_role.imagebuilder_role.id
  policy = data.aws_iam_policy_document.imagebuilder_permissions.json
}

# Create instance profile for imagebuilder instance
resource "aws_iam_instance_profile" "imagebuilder" {
  name = "${var.project}-Imagebuilder"
  role = aws_iam_role.imagebuilder_role.name
}


# Role for lifecycle managing IB Images - Lambda function
resource "aws_iam_role" "ami_retention_lambda" {
  name               = "AMI-retention-lambda-role"
  description        = "Lambda Function to handle lifecycle of AMI's created by Image Builder."
  assume_role_policy = data.aws_iam_policy_document.assume_lambda.json
}

# Policy for the Lambda function managing IB produced images 
resource "aws_iam_policy" "ami_cleaner_policy" {
  name   = "fujitsu-ami-cleaner-policy"
  policy = data.aws_iam_policy_document.lambda_amicleaner_policy.json
}

# Attach ami cleaner policy to role
resource "aws_iam_role_policy_attachment" "amicleaner-attach" {
  role       = aws_iam_role.ami_retention_lambda.name
  policy_arn = aws_iam_policy.ami_cleaner_policy.arn
}

# Attach vpc policy to role
resource "aws_iam_role_policy_attachment" "attach_vpc-amicleaner" {
  role       = aws_iam_role.ami_retention_lambda.name
  policy_arn = data.aws_iam_policy.lambdavpc.arn
}
