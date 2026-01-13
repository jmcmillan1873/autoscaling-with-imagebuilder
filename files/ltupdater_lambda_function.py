"""
Launch Template Updater Lambda Function

This Lambda function automatically updates an EC2 Launch Template with the latest
AMI ID when EC2 Image Builder completes a successful build. It's triggered by an
EventBridge rule that monitors Image Builder state change events.

Purpose:
    - Creates a new version of a Launch Template with the latest AMI ID
    - Sets the new version as the default for the Auto Scaling Group
    - Enables zero-touch AMI updates in the autoscaling infrastructure

Trigger:
    EventBridge rule detecting Image Builder "AVAILABLE" status events

Environment Variables (configured in lambda.tf):
    SSM_PARAM_NAME: Parameter Store path containing the latest AMI ID
    LAUNCH_TEMPLATE_ID: ID of the Launch Template to update
    INSTANCE_TYPE: EC2 instance type for the Launch Template
    SECURITY_GROUP_ID: Security group ID to attach to instances
    IAM_INSTANCE_PROFILE: IAM instance profile name for EC2 instances

IAM Permissions Required:
    - ssm:GetParameter: Read AMI ID from Parameter Store
    - ec2:DescribeLaunchTemplates: Query Launch Template details
    - ec2:DescribeLaunchTemplateVersions: Get version information
    - ec2:CreateLaunchTemplateVersion: Create new Launch Template version
    - ec2:ModifyLaunchTemplate: Set default version
    - logs:CreateLogGroup, logs:CreateLogStream, logs:PutLogEvents: CloudWatch logging
    - ec2:CreateNetworkInterface, ec2:DeleteNetworkInterface: VPC integration

Returns:
    dict: Response containing status code and updated AMI ID
    
Example Event Structure (from EventBridge):
    {
        "source": "aws.imagebuilder",
        "detail-type": "EC2 Image Builder Image State Change",
        "detail": {
            "state": {"status": "AVAILABLE"},
            "outputResources": {
                "amis": [{"image": "ami-xxxxx", "name": "project-name-2024-01-15"}]
            }
        }
    }

Workflow:
    1. EventBridge detects Image Builder completion (AVAILABLE status)
    2. Lambda function is triggered
    3. Function retrieves latest AMI ID from Parameter Store
    4. Creates new Launch Template version with updated AMI
    5. Sets new version as default for Auto Scaling Group
    6. New instances launched by ASG automatically use the updated AMI

Runtime: Python 3.12
Timeout: 60 seconds
VPC: Runs in private subnets for secure AWS API access
"""

# Import required libraries
import boto3  # AWS SDK for Python - used to interact with AWS services
import os     # Operating system interface - used to read environment variables

# Initialize AWS service clients
# These clients are created outside the handler to benefit from Lambda's
# execution context reuse, which improves performance on subsequent invocations
ssm = boto3.client("ssm")  # Systems Manager client for Parameter Store access
ec2 = boto3.client("ec2")  # EC2 client for Launch Template operations

# Load configuration from environment variables
# These are set by Terraform in lambda.tf and remain constant during the
# function's lifecycle. Using environment variables allows configuration
# changes without modifying code or redeploying the function
PARAM_NAME = os.environ["SSM_PARAM_NAME"]          # Parameter Store path: /imagebuilder/{project}/custom_id
LT_ID = os.environ["LAUNCH_TEMPLATE_ID"]           # Launch Template ID to update
INSTANCE_TYPE = os.environ["INSTANCE_TYPE"]        # Instance type (e.g., t4g.small)
SECURITY_GROUP_ID = os.environ["SECURITY_GROUP_ID"]  # Security group for network access
IAM_INSTANCE_PROFILE = os.environ["IAM_INSTANCE_PROFILE"]  # IAM profile for instance permissions


def handler(event, context):
    """
    Lambda handler function - main entry point for execution.
    
    This function is invoked by EventBridge when Image Builder completes
    a successful AMI build. It updates the Launch Template with the new AMI,
    ensuring that future Auto Scaling Group instances use the latest image.
    
    Args:
        event (dict): Event data from EventBridge containing Image Builder
                     state change information. While the AMI ID is in the event,
                     we read from Parameter Store for consistency and reliability.
        context (object): Lambda context object providing runtime information
                         (request ID, remaining time, memory limit, etc.)
    
    Returns:
        dict: Response object containing:
            - statusCode (int): HTTP status code (200 for success)
            - ami_id (str): The AMI ID that was applied to the Launch Template
    
    Raises:
        ClientError: If AWS API calls fail (e.g., parameter not found, permission denied)
        KeyError: If required environment variables are not set
    
    Example Return:
        {"statusCode": 200, "ami_id": "ami-0123456789abcdef"}
    """
    
    # Step 1: Retrieve the latest AMI ID from Parameter Store
    # Parameter Store is the single source of truth for the current AMI ID.
    # Image Builder automatically updates this parameter when a build completes
    # successfully. Reading from Parameter Store ensures consistency even if
    # the EventBridge event is delayed or retried.
    response = ssm.get_parameter(Name=PARAM_NAME)
    ami_id = response["Parameter"]["Value"]
    
    print(f"Retrieved AMI ID from Parameter Store: {ami_id}")

    # Step 2: Create a new version of the Launch Template
    # Launch Template versioning provides:
    # - Rollback capability if the new AMI has issues
    # - Change history and audit trail
    # - Gradual rollout capabilities
    #
    # We use SourceVersion="$Default" to copy all settings from the current
    # default version, then override only the ImageId. This ensures consistency
    # of all other settings (storage, networking, user data, etc.)
    ec2.create_launch_template_version(
        LaunchTemplateId=LT_ID,
        SourceVersion="$Default",  # Copy configuration from current default version
        LaunchTemplateData={
            "ImageId": ami_id,                          # The new AMI ID
            "InstanceType": INSTANCE_TYPE,              # Keep instance type consistent
            "SecurityGroupIds": [SECURITY_GROUP_ID],    # Maintain security group configuration
            "IamInstanceProfile": {"Name": IAM_INSTANCE_PROFILE}  # Preserve IAM permissions
        }
    )
    
    print(f"Created new Launch Template version with AMI: {ami_id}")

    # Step 3: Get the version number of the newly created version
    # We need to query the Launch Template to get the version number because
    # create_launch_template_version doesn't return it. We use the "$Latest"
    # reference to get the most recently created version (which is the one
    # we just created in the previous step).
    latest = ec2.describe_launch_template_versions(
        LaunchTemplateId=LT_ID,
        Versions=["$Latest"]  # "$Latest" is an AWS-defined constant meaning the most recent version
    )["LaunchTemplateVersions"][0]["VersionNumber"]
    
    print(f"New Launch Template version number: {latest}")

    # Step 4: Set the new version as the default
    # The Auto Scaling Group is configured to use "$Latest" (or "$Default")
    # version of the Launch Template. By setting the new version as default,
    # we ensure that future scaling events automatically use the updated AMI.
    # Existing instances continue running unaffected - they're only replaced
    # during normal scaling events or manual instance refresh operations.
    ec2.modify_launch_template(
        LaunchTemplateId=LT_ID,
        DefaultVersion=str(latest)  # Convert integer version number to string
    )

    # Log success message for CloudWatch Logs
    # This helps with troubleshooting and provides an audit trail
    print(f"Successfully updated Launch Template {LT_ID} to use AMI {ami_id}")
    
    # Return success response
    # The statusCode and ami_id can be used for monitoring and alerting
    return {
        "statusCode": 200, 
        "ami_id": ami_id
    }
