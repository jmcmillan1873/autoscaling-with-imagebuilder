# Implementation Plan: Native LT Distribution Evaluation

## Overview

This plan implements the research and evaluation activities to determine whether the native `launch_template_configuration` block in EC2 Image Builder preserves all Launch Template settings. Tasks follow the phased approach from the design: resolve blockers, add the native block alongside the existing workaround, and define verification steps. All tasks involve Terraform code changes — the actual pipeline trigger and manual CLI verification are out of scope for a coding agent.

## Tasks

- [x] 1. Resolve pre-test blockers
  - [x] 1.1 Add Launch Template lifecycle block to prevent Terraform drift
    - In `ec2-asg.tf`, add `lifecycle { ignore_changes = [latest_version, default_version] }` to the `aws_launch_template.custom_lt` resource
    - This prevents `terraform plan` from showing drift after Image Builder creates new LT versions outside Terraform
    - _Requirements: 5.1, 5.3_

  - [x] 1.2 Add IAM permissions for Image Builder to modify Launch Templates
    - In `data.tf`, add `ec2:CreateLaunchTemplateVersion` and `ec2:ModifyLaunchTemplate` to the `imagebuilder_permissions` policy document's `AllowEBSAMI` statement
    - These permissions are required for the native `launch_template_configuration` block to create new LT versions and set the default version
    - Verify the actions are not already present (current statement has `ec2:CreateImage`, `ec2:Describe*`, `ec2:CreateTags`, etc. but not the LT-specific actions)
    - _Requirements: 5.5_

- [x] 2. Checkpoint - Validate blocker resolution
  - Run `terraform validate` and `terraform plan` to confirm the lifecycle and IAM changes are syntactically correct and produce the expected plan output (only the IAM policy update, no unexpected resource changes). Ensure all tests pass, ask the user if questions arise.

- [x] 3. Add native Launch Template distribution configuration
  - [x] 3.1 Add `launch_template_configuration` block to distribution configuration
    - In `imagebuilder.tf`, add the following block inside the existing `distribution` block of `aws_imagebuilder_distribution_configuration.dist`, alongside the existing `ami_distribution_configuration` and `ssm_parameter_configuration` blocks:
      ```hcl
      launch_template_configuration {
        launch_template_id  = aws_launch_template.custom_lt.id
        account_id          = local.account_id
        set_default_version = true
      }
      ```
    - This enables the native path while keeping the Lambda/EventBridge workaround active for side-by-side comparison
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 3.1_

- [x] 4. Checkpoint - Review full plan before apply
  - Run `terraform validate` and `terraform plan` to confirm the combined changes show only: (1) IAM policy update with new LT permissions, (2) distribution configuration update with the new `launch_template_configuration` block, and (3) Launch Template lifecycle metadata change. No other resources should be affected. Ensure all tests pass, ask the user if questions arise.

- [x] 5. Add verification outputs for test inspection
  - [x] 5.1 Add outputs to surface key resource identifiers needed for CLI verification
    - In `outputs.tf`, add outputs for the distribution configuration ARN and the EventBridge rule name so the operator can easily reference them during manual verification:
      ```hcl
      output "distribution_configuration_arn" {
        description = "ARN of the Image Builder distribution configuration"
        value       = aws_imagebuilder_distribution_configuration.dist.arn
      }

      output "eventbridge_rule_name" {
        description = "Name of the EventBridge rule for Image Builder completion (for disabling during isolated testing)"
        value       = aws_cloudwatch_event_rule.imagebuilder_completed.name
      }
      ```
    - These outputs support the CLI verification commands documented in the design (Component 3) and the alternative test approach (disabling EventBridge rule)
    - _Requirements: 3.4, 4.1, 4.2, 4.3_

- [x] 6. Document workaround resource inventory as code comments
  - [x] 6.1 Add inventory comment block to `imagebuilder.tf`
    - At the top of `imagebuilder.tf` (or near the new `launch_template_configuration` block), add a comment block documenting the complete workaround resource inventory from the design, including:
      - All 10 workaround resources with their type, name, and file location
      - The single output (`ltupdater_lambda_arn`) that references workaround resources
      - Confirmation that no non-workaround resources depend on workaround resources (safe removal)
      - Cross-references from workaround resources to non-workaround resources
    - This serves as an in-repo reference for the future removal task if the native approach succeeds
    - _Requirements: 2.1, 2.2, 2.3_

- [x] 7. Final checkpoint - Validate complete evaluation setup
  - Run `terraform validate` and `terraform plan` one final time to confirm the entire evaluation setup is ready. The plan should show updates to: IAM policy, distribution configuration, Launch Template lifecycle, and new outputs. No workaround resources should be modified. Ensure all tests pass, ask the user if questions arise.

## Notes

- This plan covers only the Terraform code changes needed to set up the evaluation. The actual pipeline trigger (`aws imagebuilder start-image-pipeline-execution`) and manual CLI inspection of LT versions are operator-performed activities documented in the design.
- The workaround resources (Lambda, EventBridge, IAM) are intentionally left untouched — both paths run simultaneously during the test.
- If the evaluation succeeds, a separate follow-up spec should be created for workaround resource removal.
- Success criteria checklist and CLI verification commands are documented in the design document (Components 3 and 4).
