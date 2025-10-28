#######################################################################
# Lambda function for updating ASG Launch Template with latest AMI ID #
#######################################################################

# Role for launch template updater Lambda function
resource "aws_iam_role" "lambda-ltupdater" {
  name               = "ltupdater-role"
  assume_role_policy = data.aws_iam_policy_document.assume_lambda.json
}

# Policy for ltupdater Lambda function
resource "aws_iam_policy" "ltupdater-lambda_policy" {
  name   = "ltupdater-policy"
  policy = data.aws_iam_policy_document.lambda_ltupdater_policy.json
}

# Attach ltupdater policy to role
resource "aws_iam_role_policy_attachment" "ltupdater-attach" {
  role       = aws_iam_role.lambda-ltupdater.name
  policy_arn = aws_iam_policy.ltupdater-lambda_policy.arn
}

# Attach vpc policy to role
resource "aws_iam_role_policy_attachment" "attach_vpc-ltupdater" {
  role       = aws_iam_role.lambda-ltupdater.name
  policy_arn = data.aws_iam_policy.lambdavpc.arn
}

resource "aws_lambda_function" "update_launch_template" {
  function_name    = "ltupdater"
  role             = aws_iam_role.lambda-ltupdater.arn
  handler          = "ltupdater_lambda_function.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.ltupdater.output_path
  timeout          = 60
  source_code_hash = data.archive_file.ltupdater.output_base64sha256

  environment {
    variables = {
      SSM_PARAM_NAME       = aws_ssm_parameter.custom_built_custom_id.name
      LAUNCH_TEMPLATE_ID   = aws_launch_template.custom_lt.id
      INSTANCE_TYPE        = var.instance_type
      SECURITY_GROUP_ID    = aws_security_group.MyExampleSG.id
      IAM_INSTANCE_PROFILE = aws_iam_instance_profile.scanbox.name
    }
  }

  vpc_config {
    subnet_ids         = module.vpc.private_subnets
    security_group_ids = [aws_security_group.lambda.id]
  }
}

# Make sure Eventbridge is able to trigger our function: 
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.update_launch_template.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.imagebuilder_completed.arn
}

