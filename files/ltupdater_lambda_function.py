import boto3
import os

ssm = boto3.client("ssm")
ec2 = boto3.client("ec2")

PARAM_NAME = os.environ["SSM_PARAM_NAME"]
LT_ID = os.environ["LAUNCH_TEMPLATE_ID"]
INSTANCE_TYPE = os.environ["INSTANCE_TYPE"]
SECURITY_GROUP_ID = os.environ["SECURITY_GROUP_ID"]
IAM_INSTANCE_PROFILE = os.environ["IAM_INSTANCE_PROFILE"]

def handler(event, context):
    # Get latest AMI from SSM
    response = ssm.get_parameter(Name=PARAM_NAME)
    ami_id = response["Parameter"]["Value"]

    # Create new launch template version
    ec2.create_launch_template_version(
        LaunchTemplateId=LT_ID,
        SourceVersion="$Default",
        LaunchTemplateData={
            "ImageId": ami_id,
            "InstanceType": INSTANCE_TYPE,
            "SecurityGroupIds": [SECURITY_GROUP_ID],
            "IamInstanceProfile": {"Name": IAM_INSTANCE_PROFILE}
        }
    )

    # Set the new version as default
    latest = ec2.describe_launch_template_versions(
        LaunchTemplateId=LT_ID,
        Versions=["$Latest"]
    )["LaunchTemplateVersions"][0]["VersionNumber"]

    ec2.modify_launch_template(
        LaunchTemplateId=LT_ID,
        DefaultVersion=str(latest)
    )

    print(f"Updated LT {LT_ID} to use {ami_id}")
    return {"statusCode": 200, "ami_id": ami_id}
