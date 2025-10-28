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
