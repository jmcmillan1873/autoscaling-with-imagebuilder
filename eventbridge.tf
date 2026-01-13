################################################################################
# EventBridge Rules for Event-Driven Automation
################################################################################
# This file defines EventBridge rules that orchestrate the automated AMI
# lifecycle management workflow. EventBridge acts as the central nervous system,
# connecting Image Builder, Lambda functions, and scheduled triggers.
#
# Rules Defined:
# 1. imagebuilder_completed: Triggers when Image Builder finishes building AMI
# 2. amicleaner_schedule: Daily schedule for AMI cleanup automation
#
# Event-Driven Benefits:
# - Loose coupling between services
# - Automatic retry and error handling
# - Complete audit trail in CloudWatch
# - Scalable event processing
################################################################################

################################################################################
# Image Builder Completion Event Rule
################################################################################
# This rule monitors Image Builder state changes and triggers Lambda when
# a new AMI becomes available, enabling automatic Launch Template updates.
################################################################################

# EventBridge Rule for Image Builder State Changes
# Captures EC2 Image Builder events when AMI building completes successfully
resource "aws_cloudwatch_event_rule" "imagebuilder_completed" {
  # Rule name includes project identifier for easy identification
  name = "${var.project}-imagebuilder-completed"
  
  # Description helps operators understand rule purpose in AWS Console
  description = "Trigger on successful Image Builder builds"
  
  # Event Pattern: JSON filter for specific events
  # This pattern matches events from Image Builder service when:
  # 1. Source is "aws.imagebuilder" (EC2 Image Builder service)
  # 2. Detail type is "EC2 Image Builder Image State Change"
  # 3. State status is "AVAILABLE" (successful build completion)
  #
  # Event pattern filters out:
  # - BUILDING state (in progress)
  # - TESTING state (running tests)
  # - FAILED state (build failures)
  # - Other services' events
  #
  # Example matching event:
  # {
  #   "source": "aws.imagebuilder",
  #   "detail-type": "EC2 Image Builder Image State Change",
  #   "detail": {
  #     "state": {"status": "AVAILABLE"},
  #     "outputResources": {"amis": [{"image": "ami-xxx"}]}
  #   }
  # }
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

# EventBridge Target: Route Events to Lambda Function
# When the rule matches an event, invoke the Launch Template updater Lambda
resource "aws_cloudwatch_event_target" "trigger_lambda" {
  # Rule to attach this target to
  rule = aws_cloudwatch_event_rule.imagebuilder_completed.name
  
  # Unique identifier for this target (one rule can have multiple targets)
  target_id = "LaunchTemplateUpdater"
  
  # Lambda function ARN to invoke when event matches
  # The Lambda permission resource (in lambda.tf) grants EventBridge invoke access
  arn = aws_lambda_function.update_launch_template.arn
  
  # Note: EventBridge automatically retries failed invocations with exponential backoff
  # Failed events can be sent to DLQ for debugging (add dead_letter_config if needed)
}


################################################################################
# AMI Cleaner Schedule Rule
################################################################################
# This rule triggers the AMI cleanup Lambda function on a daily schedule,
# automating the deletion of old AMIs and snapshots to control storage costs.
################################################################################

# EventBridge Scheduled Rule for AMI Cleanup
# Creates a cron-based schedule to trigger Lambda function daily
resource "aws_cloudwatch_event_rule" "amicleaner_schedule" {
  # Rule name includes project identifier
  name = "${var.project}-amicleaner-schedule"
  
  # Description explains schedule purpose
  description = "Trigger AMI Cleaner Lambda on a schedule"
  
  # Schedule Expression: Cron format for daily execution
  # Format: cron(Minutes Hours Day-of-month Month Day-of-week Year)
  # "0 5 ? * * *" means:
  # - 0: At minute 0 (top of the hour)
  # - 5: At hour 5 (5:00 AM)
  # - ?: Any day of month (? required when day-of-week is specified)
  # - *: Every month
  # - *: Every day of week
  # - *: Every year
  #
  # Result: Runs daily at 05:00 UTC
  #
  # Why 05:00 UTC?
  # - Off-peak hours for most regions (lower AWS API load)
  # - After Image Builder Tuesday 02:00 UTC builds (3-hour buffer)
  # - Before business hours in most timezones
  #
  # Alternative schedules:
  # - "cron(0 2 ? * WED *)" - Weekly on Wednesday at 02:00 UTC
  # - "rate(1 day)" - Every 24 hours from creation time
  # - "cron(0 */6 * * ? *)" - Every 6 hours
  schedule_expression = "cron(0 5 ? * * *)" # Daily at 05:00 UTC
  
  # Schedule best practices:
  # - Avoid top-of-hour schedules (0 0 * * ? *) - high AWS load
  # - Consider timezone implications for multi-region deployments
  # - Adjust frequency based on Image Builder build frequency
  # - Monitor Lambda duration to ensure schedule doesn't overlap
}

# EventBridge Target: Route Schedule to Lambda Function
# When the schedule triggers, invoke the AMI cleaner Lambda
resource "aws_cloudwatch_event_target" "trigger_amicleaner" {
  # Rule to attach this target to
  rule = aws_cloudwatch_event_rule.amicleaner_schedule.name
  
  # Unique identifier for this target
  target_id = "AMICleaner"
  
  # Lambda function ARN to invoke on schedule
  arn = aws_lambda_function.ami_retention.arn
  
  # Note: EventBridge passes event with detail about the schedule trigger
  # Lambda function doesn't currently use event data but could be enhanced to:
  # - Accept dynamic retention counts
  # - Filter by additional criteria
  # - Report metrics to CloudWatch
}

################################################################################
# EventBridge Features Not Currently Used (Future Enhancements)
################################################################################
#
# 1. EVENT BUS
#    - Currently using default event bus
#    - Could create custom event bus for organization-wide events
#    - Enables cross-account event sharing
#
# 2. DEAD LETTER QUEUE (DLQ)
#    - Capture failed Lambda invocations for debugging
#    - Configure with: dead_letter_config block
#    - Useful for production environments
#
# 3. INPUT TRANSFORMATION
#    - Modify event payload before sending to target
#    - Extract specific fields, format data
#    - Example: Pass only AMI ID to Lambda
#
# 4. RETRY POLICY
#    - Customize retry behavior (default: 185 retries over 24 hours)
#    - Configure with: retry_policy block
#    - Useful for transient failures
#
# 5. MULTIPLE TARGETS
#    - Send same event to multiple targets
#    - Example: Lambda + SNS notification + SQS queue
#    - Enables parallel processing and notifications
#
# 6. EVENT ARCHIVE
#    - Store events for replay and analysis
#    - Useful for debugging and disaster recovery
#    - Can replay events to test changes
#
# 7. API DESTINATIONS
#    - Send events to HTTP endpoints outside AWS
#    - Enables integration with external systems
#    - Example: Webhook to Slack, PagerDuty, etc.
#
################################################################################

# Monitoring and Troubleshooting:
# - View rule invocations in EventBridge Console
# - Check Lambda function logs in CloudWatch Logs
# - Monitor rule metrics: Invocations, FailedInvocations, ThrottledRules
# - Use CloudTrail to audit rule changes and invocations
# - Test rules manually in EventBridge Console (Test Event Pattern feature)
