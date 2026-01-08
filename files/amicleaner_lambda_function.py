import os
import json
import boto3
import logging
from datetime import datetime, timezone

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ec2 = boto3.client("ec2")

RETAIN_COUNT = int(os.getenv("RETAIN_COUNT", "5"))
PROJECT_TAG_VALUE = os.getenv("PROJECT_TAG_VALUE", "MyExampleProject")
MANAGED_BY_VALUE = os.getenv("MANAGED_BY_VALUE", "AWSImageBuilder")
LAUNCH_TEMPLATE_ID = os.getenv("LAUNCH_TEMPLATE_ID")  # required for protection
DRY_RUN = os.getenv("DRY_RUN", "true").lower() == "true"


def _parse_dt(s: str) -> datetime:
    return datetime.fromisoformat(s.replace("Z", "+00:00")).astimezone(timezone.utc)


def _list_matching_amis():
    filters = [
        {"Name": "tag:Project", "Values": [PROJECT_TAG_VALUE]},
        {"Name": "tag:ManagedBy", "Values": [MANAGED_BY_VALUE]},
        {"Name": "state", "Values": ["available"]},
    ]
    resp = ec2.describe_images(Owners=["self"], Filters=filters)
    images = resp.get("Images", [])
    images.sort(key=lambda i: _parse_dt(i["CreationDate"]), reverse=True)  # newest first
    return images


def _snapshots_for_ami(image: dict) -> list[str]:
    snaps = []
    for bdm in image.get("BlockDeviceMappings", []):
        ebs = bdm.get("Ebs")
        if ebs and ebs.get("SnapshotId"):
            snaps.append(ebs["SnapshotId"])
    return snaps


def _summarise_images(images: list[dict], max_items: int = 50) -> list[dict]:
    out = []
    for img in images[:max_items]:
        out.append({
            "ImageId": img.get("ImageId"),
            "CreationDate": img.get("CreationDate"),
            "Name": img.get("Name"),
        })
    if len(images) > max_items:
        out.append({"note": f"truncated: showing {max_items} of {len(images)}"})
    return out


def _amis_referenced_by_latest_lt_versions(launch_template_id: str, protect_versions: int) -> set[str]:
    """
    Protect AMIs referenced by the *latest N* launch template versions.
    """
    protected = set()

    # Fetch versions (we'll sort and take the latest N)
    versions = []
    paginator = ec2.get_paginator("describe_launch_template_versions")
    for page in paginator.paginate(LaunchTemplateId=launch_template_id):
        versions.extend(page.get("LaunchTemplateVersions", []))

    if not versions:
        return protected

    # Sort by VersionNumber descending and take latest N
    versions.sort(key=lambda v: v.get("VersionNumber", 0), reverse=True)
    latest = versions[:protect_versions]

    for v in latest:
        data = v.get("LaunchTemplateData", {})
        image_id = data.get("ImageId")
        if image_id:
            protected.add(image_id)

    return protected


def lambda_handler(event, context):
    logger.info(
        "Starting AMI retention. retain=%s project=%s managedby=%s dry_run=%s lt_id=%s",
        RETAIN_COUNT, PROJECT_TAG_VALUE, MANAGED_BY_VALUE, DRY_RUN, LAUNCH_TEMPLATE_ID
    )

    if RETAIN_COUNT < 1:
        raise ValueError("RETAIN_COUNT must be >= 1")

    images = _list_matching_amis()
    total = len(images)
    logger.info("Found %s matching AMIs.", total)
    logger.info("Matched AMIs (newest->oldest): %s", json.dumps(_summarise_images(images)))


    if total <= RETAIN_COUNT:
        logger.info("<= %s matching AMIs; deleting none.", RETAIN_COUNT)
        return {"statusCode": 200, "body": json.dumps({"matching": total, "deleted": 0})}

    protected = set()
    if LAUNCH_TEMPLATE_ID:
        protected = _amis_referenced_by_latest_lt_versions(LAUNCH_TEMPLATE_ID, RETAIN_COUNT)
        logger.info("Protected AMIs referenced by latest %s Launch Template versions: %s",
                RETAIN_COUNT, list(sorted(protected)))
    else:
        logger.warning("LAUNCH_TEMPLATE_ID not set; NOT protecting in-use AMIs (not recommended).")

    # Keep newest RETAIN_COUNT (always)
    keep_newest = {img["ImageId"] for img in images[:RETAIN_COUNT]}

    # Eligible = older than newest RETAIN_COUNT AND not protected by LT
    older = images[RETAIN_COUNT:]
    candidates = []
    for img in older:
        ami_id = img["ImageId"]
        if ami_id in protected:
            continue
        candidates.append(img)

    logger.info("Candidates for deletion (older than newest %s, not referenced by LT): %s",
                RETAIN_COUNT, len(candidates))

    deleted = []
    for img in candidates:
        ami_id = img["ImageId"]
        snaps = _snapshots_for_ami(img)

        logger.info("Deleting AMI %s (snapshots=%s)", ami_id, snaps)

        if not DRY_RUN:
            ec2.deregister_image(ImageId=ami_id)
            for snap_id in snaps:
                ec2.delete_snapshot(SnapshotId=snap_id)

        deleted.append({"ami": ami_id, "snapshots": snaps})

    logger.info("Done. Deleted %s AMIs.", len(deleted))
    return {"statusCode": 200, "body": json.dumps({"matching": total, "deleted": len(deleted), "items": deleted})}
