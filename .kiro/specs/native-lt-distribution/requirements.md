# Requirements Document

## Introduction

AWS EC2 Image Builder historically stripped Launch Template settings (instance type, security groups, IAM instance profile, block device mappings, tags) when creating a new LT version via the native `launch_template_configuration` block — it only carried over the AMI ID. This repo works around that limitation using a custom Lambda function (`ltupdater`) triggered by EventBridge, which reads the new AMI from SSM Parameter Store and creates a fully-specified LT version.

AWS documentation now claims the native `launch_template_configuration` block preserves all existing LT settings when creating a new version. If true, the Lambda/EventBridge workaround may be unnecessary. This spec covers the research and evaluation needed to confirm that claim before committing to any implementation changes.

## Glossary

- **Image_Builder**: The AWS EC2 Image Builder service that creates custom AMIs on a schedule or on-demand.
- **Distribution_Configuration**: The `aws_imagebuilder_distribution_configuration` Terraform resource (`dist` in `imagebuilder.tf`) that controls how and where Image Builder distributes completed AMIs.
- **Launch_Template**: The `aws_launch_template` Terraform resource (`custom_lt` in `ec2-asg.tf`) that defines the EC2 instance configuration used by the Auto Scaling Group.
- **Launch_Template_Configuration_Block**: The `launch_template_configuration` block within `distribution` in the Distribution_Configuration that instructs Image Builder to natively create a new Launch Template version with the built AMI.
- **LTUpdater_Lambda**: The `ltupdater` Lambda function (in `lambda.tf`) that currently reads the AMI ID from SSM Parameter Store and creates a new Launch Template version with full settings.
- **Workaround_Resources**: The collection of resources implementing the custom fix: LTUpdater_Lambda, its IAM role (`lambda-ltupdater`), IAM policy (`ltupdater-policy`), VPC policy attachment, Lambda permission (`allow_eventbridge`), EventBridge rule (`imagebuilder_completed`), and EventBridge target (`trigger_lambda`).
- **LT_Settings**: The set of Launch Template parameters that must survive a native update: AMI ID, instance type, security group IDs, IAM instance profile, block device mappings (volume type, size, encryption), and tag specifications.
- **set_default_version**: A boolean attribute in the Launch_Template_Configuration_Block that, when true, causes Image Builder to mark the newly created Launch Template version as the default.

## Requirements

### Requirement 1: Verify Native LT Distribution Preserves Settings

**User Story:** As an infrastructure operator, I want to confirm whether the native `launch_template_configuration` block now preserves all LT_Settings when Image Builder creates a new version, so that I can determine if the workaround is still necessary.

#### Acceptance Criteria

1. WHEN Image Builder creates a new Launch Template version via the native Launch_Template_Configuration_Block, THE new version SHALL be inspected to confirm it contains the same instance type as the source version.
2. WHEN Image Builder creates a new Launch Template version via the native Launch_Template_Configuration_Block, THE new version SHALL be inspected to confirm it contains the same security group IDs as the source version.
3. WHEN Image Builder creates a new Launch Template version via the native Launch_Template_Configuration_Block, THE new version SHALL be inspected to confirm it contains the same IAM instance profile as the source version.
4. WHEN Image Builder creates a new Launch Template version via the native Launch_Template_Configuration_Block, THE new version SHALL be inspected to confirm it contains the same block device mappings (volume type, size, encryption) as the source version.
5. WHEN Image Builder creates a new Launch Template version via the native Launch_Template_Configuration_Block, THE new version SHALL be inspected to confirm it contains the same tag specifications as the source version.

### Requirement 2: Catalog Existing Workaround Resources

**User Story:** As an infrastructure operator, I want a complete inventory of all workaround resources in the repo, so that I know exactly what is in scope for removal if the native approach works.

#### Acceptance Criteria

1. THE inventory SHALL list every Terraform resource that forms part of the Workaround_Resources, including resource type, resource name, and the file where it is defined.
2. THE inventory SHALL identify any Terraform outputs that reference Workaround_Resources.
3. THE inventory SHALL identify any cross-references where non-workaround resources depend on Workaround_Resources (or vice versa).

### Requirement 3: Design a Safe Test Approach

**User Story:** As an infrastructure operator, I want a way to test the native Launch_Template_Configuration_Block without breaking the current working setup, so that I can evaluate the behavior safely.

#### Acceptance Criteria

1. THE test approach SHALL describe how to add the native Launch_Template_Configuration_Block to the Distribution_Configuration alongside the existing Workaround_Resources (both active simultaneously).
2. THE test approach SHALL document whether running both the native block and the LTUpdater_Lambda concurrently causes conflicts (e.g., race conditions creating duplicate LT versions).
3. IF running both concurrently is not safe, THEN THE test approach SHALL describe an alternative (e.g., testing in an isolated environment or temporarily disabling the EventBridge rule).
4. THE test approach SHALL include the AWS CLI commands needed to trigger a pipeline run and inspect the resulting Launch Template versions.

### Requirement 4: Define Success Criteria for the Native Approach

**User Story:** As an infrastructure operator, I want explicit pass/fail criteria for the native LT distribution test, so that the evaluation produces a clear go/no-go decision.

#### Acceptance Criteria

1. THE success criteria SHALL specify that all LT_Settings (instance type, security group IDs, IAM instance profile, block device mappings, tag specifications) are present in the new LT version created by Image Builder.
2. THE success criteria SHALL specify that `set_default_version = true` causes the new version to be marked as the default version of the Launch_Template.
3. THE success criteria SHALL specify that the ASG can reference the new LT version (via `$Latest` or `$Default`) and would launch functional instances from it.
4. IF any LT_Setting is missing or altered in the new version, THEN THE evaluation SHALL be considered a failure and the workaround remains necessary.

### Requirement 5: Document Risks and Unknowns

**User Story:** As an infrastructure operator, I want a record of known risks and open questions before testing, so that I can make an informed decision and avoid surprises.

#### Acceptance Criteria

1. THE risk documentation SHALL address whether Terraform will detect drift on `latest_version` or `default_version` attributes of the Launch_Template when Image Builder creates new versions outside of Terraform.
2. THE risk documentation SHALL address how `set_default_version` interacts with the ASG's `version = "$Latest"` reference — specifically whether `$Latest` and `$Default` diverge.
3. THE risk documentation SHALL address whether the existing `lifecycle { ignore_changes = [value] }` on the SSM_Parameter is sufficient, or if additional lifecycle blocks are needed on the Launch_Template.
4. THE risk documentation SHALL note any AWS documentation or changelog references that confirm the behavior change for the native Launch_Template_Configuration_Block.
5. IF any risk is identified as a blocker, THEN THE risk documentation SHALL flag it as requiring resolution before testing proceeds.
