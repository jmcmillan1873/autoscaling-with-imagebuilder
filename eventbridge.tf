# This is used to trigger lambda to update the ASG Launch template when there's a new AMI available.

resource "aws_cloudwatch_event_rule" "imagebuilder_completed" {
  name          = "${var.project}-imagebuilder-completed"
  description   = "Trigger on successful Image Builder builds"
  event_pattern = <<EOF
{
  "source": ["aws.imagebuilder"],
  "detail-type": ["EC2 Image Builder Image State Change"],
  "detail": {
    "state": {
      "status": ["AVAILABLE"]
    }
  }
}
EOF
}

resource "aws_cloudwatch_event_target" "trigger_lambda" {
  rule      = aws_cloudwatch_event_rule.imagebuilder_completed.name
  target_id = "LaunchTemplateUpdater"
  arn       = aws_lambda_function.update_launch_template.arn
}

## Create Event Bridge Cron schedule and target to trigger AMI cleaner Lambda ##
resource "aws_cloudwatch_event_rule" "amicleaner_schedule" {
  name                = "${var.project}-amicleaner-schedule"
  description         = "Trigger AMI Cleaner Lambda on a schedule"
  schedule_expression = "cron(0 5 ? * * *)" # Daily at 05:00 UTC
}

resource "aws_cloudwatch_event_target" "trigger_amicleaner" {
  rule      = aws_cloudwatch_event_rule.amicleaner_schedule.name
  target_id = "AMICleaner"
  arn       = aws_lambda_function.ami_retention.arn
}
