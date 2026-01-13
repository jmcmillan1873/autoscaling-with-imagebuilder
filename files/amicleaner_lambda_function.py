"""
AMI Cleaner Lambda Function - Automated AMI Lifecycle Management

This Lambda function performs automated cleanup of old AMIs created by EC2 Image Builder,
preventing AMI accumulation and reducing EBS snapshot storage costs. It intelligently
retains the newest N AMIs and deletes older ones while protecting AMIs currently
referenced by Launch Template versions.

Purpose:
    - Delete old AMIs that exceed the retention count
    - Clean up associated EBS snapshots to reduce storage costs
    - Protect AMIs referenced by recent Launch Template versions
    - Prevent accidental deletion of in-use AMIs

Trigger:
    EventBridge scheduled rule (daily at 05:00 UTC)

Environment Variables (configured in lambda.tf):
    RETAIN_COUNT: Number of newest AMIs to keep (default: 5)
    PROJECT_TAG_VALUE: Project tag value to filter AMIs (e.g., "MyExampleProject")
    MANAGED_BY_VALUE: ManagedBy tag value to filter AMIs (default: "AWSImageBuilder")
    LAUNCH_TEMPLATE_ID: Launch Template ID to check for AMI references
    DRY_RUN: If "true", logs actions without deleting (default: "true")

IAM Permissions Required:
    - ec2:DescribeImages: List and filter AMIs by tags
    - ec2:DescribeSnapshots: Identify snapshots associated with AMIs
    - ec2:DescribeLaunchTemplates: Access Launch Template details
    - ec2:DescribeLaunchTemplateVersions: Check which AMIs are in use
    - ec2:DeregisterImage: Delete AMIs
    - ec2:DeleteSnapshot: Remove associated EBS snapshots
    - logs:CreateLogGroup, logs:CreateLogStream, logs:PutLogEvents: CloudWatch logging
    - ec2:CreateNetworkInterface, ec2:DeleteNetworkInterface: VPC integration

Safety Mechanisms:
    1. Only processes AMIs with specific Project and ManagedBy tags
    2. Always retains the newest RETAIN_COUNT AMIs regardless of usage
    3. Protects AMIs referenced by the latest RETAIN_COUNT Launch Template versions
    4. DRY_RUN mode (default) logs actions without deleting
    5. Comprehensive logging for audit trail and troubleshooting

Deletion Logic:
    - Keep: Newest RETAIN_COUNT AMIs (sorted by creation date)
    - Keep: AMIs referenced by latest RETAIN_COUNT Launch Template versions
    - Delete: Older AMIs not protected by either rule above
    - Also Delete: EBS snapshots associated with deleted AMIs

Example Scenario (RETAIN_COUNT=5):
    AMIs by age: [AMI-1(newest), AMI-2, AMI-3, AMI-4, AMI-5, AMI-6, AMI-7(oldest)]
    LT versions reference: AMI-1, AMI-5, AMI-6
    Result:
        - Keep: AMI-1, AMI-2, AMI-3, AMI-4, AMI-5 (newest 5)
        - Keep: AMI-6 (referenced by LT but older than newest 5)
        - Delete: AMI-7 (older than newest 5 and not in LT)

Returns:
    dict: Response containing match count, deletion count, and deleted AMI details

Runtime: Python 3.12
Timeout: 300 seconds (5 minutes)
VPC: Runs in private subnets for secure AWS API access
"""

# Import required libraries
import os        # Operating system interface - for environment variables
import json      # JSON encoding/decoding - for structured logging and response
import boto3     # AWS SDK for Python - for EC2 API operations
import logging   # Python logging - for structured output to CloudWatch Logs
from datetime import datetime, timezone  # Date/time handling - for parsing AMI creation dates

# Configure logging
# The Lambda runtime captures stdout/stderr and sends to CloudWatch Logs
# INFO level provides sufficient detail for operational monitoring
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize EC2 client outside handler for execution context reuse
# This improves performance on subsequent Lambda invocations
ec2 = boto3.client("ec2")

# Load configuration from environment variables
# Defaults are provided for safety and development/testing scenarios
# IMPORTANT: DRY_RUN defaults to "true" to prevent accidental deletions

# Number of most recent AMIs to always retain
RETAIN_COUNT = int(os.getenv("RETAIN_COUNT", "5"))

# Tag values used to filter AMIs - only AMIs with both tags are considered for deletion
PROJECT_TAG_VALUE = os.getenv("PROJECT_TAG_VALUE", "MyExampleProject")
MANAGED_BY_VALUE = os.getenv("MANAGED_BY_VALUE", "AWSImageBuilder")

# Launch Template ID to check for AMI usage - prevents deletion of in-use AMIs
LAUNCH_TEMPLATE_ID = os.getenv("LAUNCH_TEMPLATE_ID")

# Dry run mode - when true, logs actions without actually deleting
# This is a safety mechanism to validate logic before enabling deletion
# To enable deletion: set DRY_RUN="false" in lambda.tf environment variables
DRY_RUN = os.getenv("DRY_RUN", "true").lower() == "true"


# Helper Functions
# These utility functions encapsulate specific operations for better code organization
# and reusability. They're defined before lambda_handler since Python requires
# functions to be defined before they're called.


def _parse_dt(s: str) -> datetime:
    """
    Parse ISO 8601 timestamp string to timezone-aware datetime object.
    
    AMI CreationDate from AWS API is in ISO 8601 format with 'Z' suffix
    (e.g., "2024-01-15T10:30:45.000Z"). This function converts it to a
    Python datetime object in UTC timezone for consistent sorting and comparison.
    
    Args:
        s (str): ISO 8601 timestamp string from AWS API (e.g., "2024-01-15T10:30:45.000Z")
    
    Returns:
        datetime: Timezone-aware datetime object in UTC
    
    Example:
        >>> _parse_dt("2024-01-15T10:30:45.000Z")
        datetime.datetime(2024, 1, 15, 10, 30, 45, tzinfo=datetime.timezone.utc)
    """
    # Replace 'Z' with '+00:00' for proper ISO 8601 parsing
    # Then convert to UTC timezone for consistent comparisons
    return datetime.fromisoformat(s.replace("Z", "+00:00")).astimezone(timezone.utc)


def _list_matching_amis():
    """
    Retrieve all AMIs that match the configured tag filters.
    
    Queries EC2 for AMIs owned by the current account that have:
    - Tag "Project" matching PROJECT_TAG_VALUE
    - Tag "ManagedBy" matching MANAGED_BY_VALUE
    - State "available" (not pending, failed, or deregistered)
    
    The results are sorted by creation date (newest first) to facilitate
    retention logic.
    
    Returns:
        list[dict]: List of AMI dictionaries from describe_images API,
                    sorted by CreationDate in descending order (newest first)
    
    Example AMI dict structure:
        {
            "ImageId": "ami-0123456789abcdef",
            "CreationDate": "2024-01-15T10:30:45.000Z",
            "Name": "MyProject-2024-01-15",
            "BlockDeviceMappings": [...],
            "Tags": [{"Key": "Project", "Value": "MyProject"}, ...]
        }
    """
    # Define filters to narrow down AMI search
    # Filters are applied server-side by AWS, reducing data transfer and processing
    filters = [
        {"Name": "tag:Project", "Values": [PROJECT_TAG_VALUE]},    # Match project tag
        {"Name": "tag:ManagedBy", "Values": [MANAGED_BY_VALUE]},   # Match managed-by tag
        {"Name": "state", "Values": ["available"]},                 # Only available AMIs
    ]
    
    # Query EC2 API for matching AMIs
    # Owners=["self"] limits results to AMIs owned by the current account
    resp = ec2.describe_images(Owners=["self"], Filters=filters)
    images = resp.get("Images", [])
    
    # Sort AMIs by creation date, newest first
    # This ordering is critical for the retention logic - we keep the first N items
    images.sort(key=lambda i: _parse_dt(i["CreationDate"]), reverse=True)
    
    return images


def _snapshots_for_ami(image: dict) -> list[str]:
    """
    Extract EBS snapshot IDs associated with an AMI.
    
    When an AMI is created, it includes references to EBS snapshots for each
    volume. These snapshots must be deleted separately from the AMI to fully
    reclaim storage and reduce costs. This function extracts snapshot IDs
    from the AMI's block device mappings.
    
    Args:
        image (dict): AMI dictionary from describe_images API
    
    Returns:
        list[str]: List of snapshot IDs (e.g., ["snap-abc123", "snap-def456"])
                   Returns empty list if no EBS snapshots are found
    
    Note:
        - Instance store-backed AMIs have no EBS snapshots
        - Some block device mappings may not have snapshots (ephemeral volumes)
    
    Example block device mapping:
        {
            "DeviceName": "/dev/xvda",
            "Ebs": {
                "SnapshotId": "snap-0123456789abcdef",
                "VolumeSize": 20,
                "VolumeType": "gp3",
                "Encrypted": true
            }
        }
    """
    snaps = []
    
    # Iterate through all block device mappings in the AMI
    for bdm in image.get("BlockDeviceMappings", []):
        ebs = bdm.get("Ebs")
        
        # Check if this mapping has an EBS volume with a snapshot
        if ebs and ebs.get("SnapshotId"):
            snaps.append(ebs["SnapshotId"])
    
    return snaps


def _summarise_images(images: list[dict], max_items: int = 50) -> list[dict]:
    """
    Create a concise summary of AMIs for logging purposes.
    
    Reduces verbose AMI dictionaries to essential fields for logging.
    This improves log readability and reduces CloudWatch Logs costs by
    avoiding logging of large, unnecessary data structures.
    
    Args:
        images (list[dict]): Full AMI dictionaries from describe_images API
        max_items (int): Maximum number of items to include (default: 50)
    
    Returns:
        list[dict]: Simplified AMI summaries with only key fields:
                    - ImageId: AMI identifier
                    - CreationDate: When the AMI was created
                    - Name: Human-readable AMI name
    
    Example output:
        [
            {
                "ImageId": "ami-abc123",
                "CreationDate": "2024-01-15T10:30:45.000Z",
                "Name": "MyProject-2024-01-15"
            },
            ...
        ]
    
    If more than max_items images exist, adds a truncation note to the output.
    """
    out = []
    
    # Extract essential fields from first max_items images
    for img in images[:max_items]:
        out.append({
            "ImageId": img.get("ImageId"),
            "CreationDate": img.get("CreationDate"),
            "Name": img.get("Name"),
        })
    
    # Add truncation notice if we're not showing all images
    if len(images) > max_items:
        out.append({"note": f"truncated: showing {max_items} of {len(images)}"})
    
    return out


def _amis_referenced_by_latest_lt_versions(launch_template_id: str, protect_versions: int) -> set[str]:
    """
    Identify AMIs that are currently in use by recent Launch Template versions.
    
    This function prevents deletion of AMIs that are referenced by the most recent
    Launch Template versions. This is critical because:
    1. Deleting an in-use AMI causes Launch Template to fail when launching instances
    2. Rolling back to a previous Launch Template version would fail if AMI is deleted
    3. Auto Scaling Group may reference older versions during instance refresh
    
    The function protects AMIs from the latest N Launch Template versions, where
    N = protect_versions (typically same as RETAIN_COUNT).
    
    Args:
        launch_template_id (str): Launch Template ID to query (e.g., "lt-0123456789abcdef")
        protect_versions (int): Number of latest versions to check for AMI references
    
    Returns:
        set[str]: Set of AMI IDs that are protected from deletion
                  Empty set if no versions exist or Launch Template ID is invalid
    
    Example:
        If Launch Template has versions:
        - v10 (latest) -> ami-abc (protected)
        - v9 -> ami-xyz (protected)
        - v8 -> ami-def (protected)
        - v7 -> ami-ghi (protected)
        - v6 -> ami-jkl (protected)
        - v5 -> ami-mno (not protected if protect_versions=5)
        
        Returns: {"ami-abc", "ami-xyz", "ami-def", "ami-ghi", "ami-jkl"}
    
    Note:
        - Uses pagination to handle Launch Templates with many versions
        - Sorts versions by version number (descending) to get most recent
        - Handles cases where multiple versions reference the same AMI
    """
    protected = set()  # Use set to automatically deduplicate AMI IDs

    # Fetch all versions using pagination
    # Launch Templates can have hundreds of versions, so we must paginate
    versions = []
    paginator = ec2.get_paginator("describe_launch_template_versions")
    
    # Iterate through all pages of results
    for page in paginator.paginate(LaunchTemplateId=launch_template_id):
        versions.extend(page.get("LaunchTemplateVersions", []))

    # Return empty set if no versions found
    if not versions:
        return protected

    # Sort versions by version number in descending order (newest first)
    # VersionNumber is an integer starting at 1 and incrementing
    versions.sort(key=lambda v: v.get("VersionNumber", 0), reverse=True)
    
    # Take only the latest N versions
    latest = versions[:protect_versions]

    # Extract AMI ID from each version's LaunchTemplateData
    for v in latest:
        data = v.get("LaunchTemplateData", {})
        image_id = data.get("ImageId")
        
        # Add to protected set if ImageId exists
        if image_id:
            protected.add(image_id)

    return protected


def lambda_handler(event, context):
    """
    Lambda handler function - main entry point for AMI cleanup execution.
    
    This function orchestrates the complete AMI lifecycle management workflow:
    1. Validates configuration
    2. Discovers matching AMIs
    3. Identifies protection rules (newest N + Launch Template references)
    4. Determines which AMIs can be safely deleted
    5. Deletes AMIs and associated snapshots (unless DRY_RUN=true)
    6. Returns summary of actions taken
    
    Args:
        event (dict): Event data from EventBridge (scheduled trigger)
                     Not currently used, but reserved for future enhancements
                     (e.g., dynamic retention counts, project filtering)
        context (object): Lambda context object with runtime information
                         (request ID, remaining time, memory limit, etc.)
    
    Returns:
        dict: Response object containing:
            - statusCode (int): HTTP status code (200 for success)
            - body (str): JSON string with execution summary:
                - matching (int): Total number of matching AMIs found
                - deleted (int): Number of AMIs deleted
                - items (list): Details of deleted AMIs and snapshots
    
    Raises:
        ValueError: If RETAIN_COUNT < 1 (invalid configuration)
        ClientError: If AWS API calls fail (permission denied, resource not found, etc.)
    
    Example Return (DRY_RUN=true):
        {
            "statusCode": 200,
            "body": "{\"matching\": 10, \"deleted\": 3, \"items\": [...]}"
        }
    
    Workflow Overview:
        - RETAIN_COUNT=5, 10 matching AMIs found
        - Newest 5 AMIs are always protected
        - Check latest 5 Launch Template versions for AMI references
        - AMIs outside newest 5 AND not in LT = candidates for deletion
        - Delete candidates (and their snapshots) unless DRY_RUN=true
    """
    
    # Log execution start with key configuration parameters
    # This helps with troubleshooting and provides an audit trail
    logger.info(
        "Starting AMI retention cleanup. Configuration: retain=%s project=%s managedby=%s dry_run=%s lt_id=%s",
        RETAIN_COUNT, 
        PROJECT_TAG_VALUE, 
        MANAGED_BY_VALUE, 
        DRY_RUN, 
        LAUNCH_TEMPLATE_ID
    )

    # Validate configuration - retain count must be at least 1
    # This prevents accidentally deleting all AMIs
    if RETAIN_COUNT < 1:
        raise ValueError("RETAIN_COUNT must be >= 1")

    # Step 1: Discover all AMIs matching the configured tags
    # Returns AMIs sorted by creation date (newest first)
    images = _list_matching_amis()
    total = len(images)
    
    logger.info("Found %s matching AMIs.", total)
    
    # Log summary of discovered AMIs for audit and troubleshooting
    # Using json.dumps for structured logging that's easy to parse
    logger.info(
        "Matched AMIs (newest->oldest): %s", 
        json.dumps(_summarise_images(images))
    )

    # Step 2: Check if deletion is needed
    # If we have fewer AMIs than the retention count, nothing needs to be deleted
    if total <= RETAIN_COUNT:
        logger.info(
            "Only %s AMIs found, which is <= retention count of %s. Nothing to delete.",
            total,
            RETAIN_COUNT
        )
        return {
            "statusCode": 200, 
            "body": json.dumps({
                "matching": total, 
                "deleted": 0,
                "message": "Below retention threshold"
            })
        }

    # Step 3: Identify AMIs that must be protected from deletion
    # Protection rules:
    # 1. Always protect newest RETAIN_COUNT AMIs (already sorted newest first)
    # 2. Protect AMIs referenced by latest RETAIN_COUNT Launch Template versions
    
    protected = set()  # Set of AMI IDs that cannot be deleted
    
    # Check Launch Template for AMI usage if LAUNCH_TEMPLATE_ID is configured
    if LAUNCH_TEMPLATE_ID:
        protected = _amis_referenced_by_latest_lt_versions(LAUNCH_TEMPLATE_ID, RETAIN_COUNT)
        logger.info(
            "Protected AMIs referenced by latest %s Launch Template versions: %s",
            RETAIN_COUNT, 
            list(sorted(protected))  # Sort for consistent logging
        )
    else:
        # Warning if Launch Template check is disabled
        # This is risky because we might delete AMIs that are in use
        logger.warning(
            "LAUNCH_TEMPLATE_ID not set; NOT protecting in-use AMIs. "
            "This is not recommended as it may delete AMIs currently referenced by Launch Templates."
        )

    # Step 4: Identify newest RETAIN_COUNT AMIs (always keep these)
    # Since images are already sorted newest first, just take the first N
    keep_newest = {img["ImageId"] for img in images[:RETAIN_COUNT]}
    
    logger.info(
        "Always keeping newest %s AMIs: %s",
        RETAIN_COUNT,
        list(sorted(keep_newest))
    )

    # Step 5: Determine deletion candidates
    # Candidates are AMIs that are:
    # - Older than the newest RETAIN_COUNT (not in keep_newest)
    # - NOT referenced by recent Launch Template versions (not in protected)
    
    older = images[RETAIN_COUNT:]  # All AMIs older than newest RETAIN_COUNT
    candidates = []
    
    for img in older:
        ami_id = img["ImageId"]
        
        # Skip if AMI is protected by Launch Template reference
        if ami_id in protected:
            logger.info(
                "Skipping AMI %s: older than newest %s but referenced by Launch Template",
                ami_id,
                RETAIN_COUNT
            )
            continue
        
        # This AMI can be safely deleted
        candidates.append(img)

    logger.info(
        "Found %s candidates for deletion (older than newest %s and not referenced by Launch Template)",
        len(candidates),
        RETAIN_COUNT
    )

    # Step 6: Delete candidate AMIs and their snapshots
    # Track deleted items for the response
    deleted = []
    
    for img in candidates:
        ami_id = img["ImageId"]
        
        # Extract snapshot IDs associated with this AMI
        # These must be deleted separately to fully reclaim storage
        snaps = _snapshots_for_ami(img)

        logger.info(
            "Deleting AMI %s (name=%s, created=%s, snapshots=%s)",
            ami_id,
            img.get("Name"),
            img.get("CreationDate"),
            snaps
        )

        # Perform deletion unless in dry-run mode
        if not DRY_RUN:
            # Deregister the AMI (makes it unavailable but doesn't delete snapshots)
            ec2.deregister_image(ImageId=ami_id)
            
            # Delete each associated snapshot
            # Each snapshot incurs storage costs, so deletion is important
            for snap_id in snaps:
                ec2.delete_snapshot(SnapshotId=snap_id)
            
            logger.info("Successfully deleted AMI %s and %s snapshots", ami_id, len(snaps))
        else:
            # Dry-run mode: log what would be deleted without actually deleting
            logger.info(
                "DRY_RUN mode: Would delete AMI %s and %s snapshots (not actually deleting)",
                ami_id,
                len(snaps)
            )

        # Track deletion for response
        deleted.append({
            "ami": ami_id,
            "name": img.get("Name"),
            "created": img.get("CreationDate"),
            "snapshots": snaps
        })

    # Step 7: Log completion summary
    if DRY_RUN:
        logger.info(
            "DRY_RUN complete. Would have deleted %s AMIs (not actually deleted). "
            "Set DRY_RUN=false in lambda.tf to enable actual deletion.",
            len(deleted)
        )
    else:
        logger.info("Cleanup complete. Successfully deleted %s AMIs.", len(deleted))
    
    # Return summary response
    return {
        "statusCode": 200, 
        "body": json.dumps({
            "matching": total,           # Total number of matching AMIs found
            "deleted": len(deleted),     # Number of AMIs deleted (or would be deleted)
            "dry_run": DRY_RUN,         # Whether this was a dry run
            "items": deleted             # Details of deleted items
        })
    }
