################################################################################
# EC2 Image Builder Pipeline Configuration
################################################################################
# This file defines the complete Image Builder pipeline that creates custom,
# hardened AMIs automatically. The pipeline includes components (build steps),
# a recipe (ordered component execution), infrastructure configuration,
# distribution settings, and scheduling.
################################################################################

################################################################################
# Image Builder Components - Build Steps
################################################################################
# Components are reusable scripts that run during AMI creation. They install
# packages, configure settings, and customize the base AMI. Components are
# executed in the order defined in the image recipe.
################################################################################

# Custom Scripts Component
# Downloads and installs project-specific scripts and configurations
resource "aws_imagebuilder_component" "custom_scripts" {
  # Component name - appears in Image Builder console and logs
  name = "download-custom-scripts"
  
  # Platform: Linux or Windows (determines available commands)
  platform = "Linux"
  
  # Semantic version (major.minor.patch)
  # Increment version when updating the component to track changes
  version = "1.0.0"

  # Component definition from template file
  # Template allows dynamic values (like region) to be injected
  # Template syntax: YAML format with Image Builder Document schema
  data = templatefile("${path.module}/files/imagebuilder_component_custom_scripts.tpl", {
    region = var.region
  })
}

# OS Tooling Component
# Installs standard operating system packages and tools
resource "aws_imagebuilder_component" "os_tooling" {
  name     = "al2023-os-tooling"
  platform = "Linux"
  version  = "1.0.0"
  
  # Template file with no dynamic variables
  data = templatefile("${path.module}/files/imagebuilder_component_os_tools.tpl", {})
}

################################################################################
# Image Builder Recipe - Component Execution Order
################################################################################
# The recipe defines which base AMI to use, which components to execute,
# and in what order. It also configures storage for the resulting AMI.
################################################################################

resource "aws_imagebuilder_image_recipe" "custom_recipe" {
  # Recipe name - used for identification and tracking
  name = "al2023-custom-recipe"
  
  # Semantic version - increment when changing components or configuration
  version = "1.0.0"
  
  # Base (parent) AMI - starting point for customization
  # Uses Amazon Linux 2023 ARM64 from Parameter Store (data.tf)
  # AWS updates this parameter regularly with the latest AL2023 AMI
  parent_image = data.aws_ssm_parameter.al2023.value

  # Components to execute during build (in order)
  # Order matters: os_tooling runs first, then custom_scripts
  # Each component can depend on previous components' changes
  component { component_arn = aws_imagebuilder_component.os_tooling.arn }
  component { component_arn = aws_imagebuilder_component.custom_scripts.arn }

  # Storage configuration for the resulting AMI
  # This overrides the parent AMI's block device configuration
  block_device_mapping {
    device_name = "/dev/xvda"  # Root volume device
    
    ebs {
      # GP3 volumes provide better price/performance than GP2
      volume_type = "gp3"
      
      # 20 GB root volume size
      # Base AL2023 is ~2-3 GB, leaving room for customizations
      volume_size = 20
      
      # Encrypt at rest using AWS-managed keys
      # Required for compliance and security best practices
      encrypted = true
      
      # Delete volume when AMI is deregistered
      # Prevents orphaned volumes and reduces storage costs
      delete_on_termination = true
    }
  }

  # Lifecycle management - recreate recipe before destroying old one
  # Prevents downtime if the pipeline references this recipe
  lifecycle {
    create_before_destroy = true
  }

  # Tags for tracking and management
  tags = {
    ManagedBy = "AWSImageBuilder"
  }
}

################################################################################
# Image Builder Infrastructure Configuration
################################################################################
# Defines where and how Image Builder instances are launched during builds.
# Specifies VPC, subnets, security groups, IAM roles, and instance types.
################################################################################

resource "aws_imagebuilder_infrastructure_configuration" "infra" {
  # Configuration name
  name = "al2023-custom-infra"
  
  # IAM instance profile for build instances
  # Grants permissions to create AMIs, access S3, use Systems Manager
  instance_profile_name = aws_iam_instance_profile.imagebuilder.name
  
  # Instance types to use for building AMIs
  # Multiple types provide flexibility - Image Builder selects based on availability
  # From variables.tf - typically t4g.small through t4g.2xlarge
  instance_types = var.build_instance_types
  
  # Subnet for build instance placement
  # Uses first private subnet for security (no direct internet access)
  # Build instances access internet via NAT Gateway for package downloads
  subnet_id = module.vpc.private_subnets[0]
  
  # Security group allowing HTTPS egress for AWS APIs and package repos
  security_group_ids = [aws_security_group.MyExampleSG.id]
  
  # Terminate instance on failure to avoid charges for stuck instances
  # Build instances are temporary - no need to keep them after failure
  terminate_instance_on_failure = true

  tags = {
    Name      = "al2023-custom-imagebuilding"
    ManagedBy = "AWSImageBuilder"
  }
}

################################################################################
# Image Builder Distribution Configuration
################################################################################
# Controls how and where AMIs are distributed after successful builds.
# Handles AMI naming, tagging, and Parameter Store updates.
# Supports single-region or multi-region distribution.
################################################################################

resource "aws_imagebuilder_distribution_configuration" "dist" {
  # Distribution configuration name
  name = "${var.project}-dist"

  # Distribution settings for target region(s)
  # Currently configured for single-region deployment
  # Can be duplicated for multi-region distribution
  distribution {
    # Target region for AMI distribution
    region = var.region

    # AMI distribution settings
    ami_distribution_configuration {
      # AMI name with build date
      # {{imagebuilder:buildDate}} is replaced with actual build date (YYYY-MM-DD-HHmm)
      # Example result: "MyExampleProject-2024-01-15-1430"
      name = "${var.project}-{{imagebuilder:buildDate}}"
      
      # Human-readable description visible in EC2 AMI list
      description = "Custom pre-baked AL2023 image"

      # Tags applied to created AMIs
      # These tags enable filtering, cost tracking, and automation
      ami_tags = {
        OS        = "AmazonLinux2023"          # Operating system identifier
        Hardened  = "true"                      # Indicates security hardening applied
        Name      = "${var.project}-{{imagebuilder:buildDate}}"  # Duplicate name as tag
        ManagedBy = "AWSImageBuilder"           # Identifies Image Builder-created AMIs
        Project   = var.project                 # Project identifier for grouping
      }
    }

    # Parameter Store integration
    # Automatically updates SSM parameter with new AMI ID after successful build
    # This enables automatic Launch Template updates via Lambda function
    ssm_parameter_configuration {
      # Parameter to update (defined in ssm.tf)
      parameter_name = aws_ssm_parameter.custom_built_custom_id.name
      
      # Account ID where parameter exists
      # Uses local.account_id for current account (from data.tf)
      ami_account_id = local.account_id
    }

    ############################################################################
    # Workaround Resource Inventory (for future removal if native approach works)
    ############################################################################
    # The following resources implement the Lambda/EventBridge workaround that
    # creates fully-specified LT versions after each Image Builder build. If the
    # native launch_template_configuration block below proves to preserve all LT
    # settings, these resources can be safely removed.
    #
    # Workaround Resources:
    #   Type                                Name                    File
    #   ----                                ----                    ----
    #   aws_iam_role                        lambda-ltupdater        iam.tf
    #   aws_iam_policy                      ltupdater-lambda_policy iam.tf
    #   aws_iam_role_policy_attachment      ltupdater-attach        iam.tf
    #   aws_iam_role_policy_attachment      attach_vpc-ltupdater    iam.tf
    #   aws_lambda_function                 update_launch_template  lambda.tf
    #   aws_lambda_permission               allow_eventbridge       lambda.tf
    #   aws_cloudwatch_event_rule           imagebuilder_completed  eventbridge.tf
    #   aws_cloudwatch_event_target         trigger_lambda          eventbridge.tf
    #   data.archive_file                   ltupdater               data.tf
    #   (source file)                       ltupdater_lambda_function.py  files/
    #
    # Output referencing workaround resources:
    #   ltupdater_lambda_arn  (outputs.tf) -> aws_lambda_function.update_launch_template.arn
    #
    # Cross-references (workaround -> non-workaround):
    #   aws_lambda_function.update_launch_template depends on:
    #     - aws_ssm_parameter.custom_built_custom_id  (env var, lambda.tf)
    #     - aws_launch_template.custom_lt              (env var, lambda.tf)
    #     - aws_security_group.MyExampleSG             (env var, lambda.tf)
    #     - aws_iam_instance_profile.scanbox           (env var, lambda.tf)
    #     - aws_security_group.lambda                  (vpc_config, lambda.tf)
    #     - module.vpc.private_subnets                 (vpc_config, lambda.tf)
    #
    # No non-workaround resources depend on workaround resources (safe removal).
    ############################################################################

    # Native Launch Template version creation
    # Instructs Image Builder to create a new LT version with the built AMI
    # while preserving all existing LT settings (instance type, security groups,
    # IAM instance profile, block device mappings, tag specifications).
    # This runs alongside the Lambda/EventBridge workaround for side-by-side comparison.
    launch_template_configuration {
      launch_template_id = aws_launch_template.custom_lt.id
      account_id         = local.account_id
      default            = true
    }
  }

  tags = {
    ManagedBy = "AWSImageBuilder"
  }
}

################################################################################
# Image Builder Pipeline - Orchestration and Scheduling
################################################################################
# The pipeline ties together all Image Builder components and executes builds
# on a schedule. It orchestrates the entire AMI creation workflow from
# instance launch to AMI distribution.
################################################################################

resource "aws_imagebuilder_image_pipeline" "pipeline" {
  # Pipeline name - appears in console and CloudWatch events
  name = "${var.project}-pipeline"
  
  # ARN of the recipe to use (components + base image + storage config)
  image_recipe_arn = aws_imagebuilder_image_recipe.custom_recipe.arn
  
  # ARN of infrastructure config (VPC, subnets, instance types, IAM)
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.infra.arn
  
  # ARN of distribution config (AMI naming, tagging, Parameter Store update)
  distribution_configuration_arn = aws_imagebuilder_distribution_configuration.dist.arn
  
  # Pipeline status - ENABLED allows scheduled builds to execute
  # Set to DISABLED to pause scheduled builds (manual builds still possible)
  status = "ENABLED"
  
  # Enhanced metadata collection
  # Collects additional information about the build (packages, versions, etc.)
  # Useful for compliance, auditing, and troubleshooting
  enhanced_image_metadata_enabled = true

  # Build schedule
  # Defines when the pipeline automatically triggers builds
  schedule {
    # Cron expression: "0 2 ? * TUE *"
    # Format: minute hour day-of-month month day-of-week year
    # Breakdown:
    # - 0: At minute 0 (top of the hour)
    # - 2: At hour 2 (02:00 UTC / 2:00 AM UTC)
    # - ?: Any day of month (required when day-of-week is specified)
    # - *: Every month
    # - TUE: Tuesday only
    # - *: Every year
    #
    # Result: Every Tuesday at 02:00 UTC
    #
    # Why Tuesday at 02:00 UTC?
    # - Off-peak hours (low AWS API load)
    # - Microsoft Patch Tuesday is the second Tuesday of each month
    # - Allows time for OS security patches to be released and tested
    # - Before business hours in most time zones
    #
    # Alternative schedules:
    # - Daily: "cron(0 2 * * ? *)"
    # - Weekly Sunday: "cron(0 2 ? * SUN *)"
    # - Monthly (1st): "cron(0 2 1 * ? *)"
    # - Bi-weekly: Use two separate schedules or external orchestration
    schedule_expression = "cron(0 2 ? * TUE *)"
    
    # Pipeline execution start condition
    # EXPRESSION_MATCH_ONLY: Only start when schedule matches
    # EXPRESSION_MATCH_AND_DEPENDENCY_UPDATES_AVAILABLE: Also start when base image updates
    #
    # Current setting ensures predictable weekly builds regardless of upstream changes
    # Alternative would trigger additional builds when Amazon Linux 2023 updates
    pipeline_execution_start_condition = "EXPRESSION_MATCH_ONLY"
  }

  # Image testing configuration
  # Image Builder can run automated tests on created AMIs before distribution
  image_tests_configuration {
    # Enable testing - recommended for production pipelines
    # Tests verify the AMI boots and passes basic functionality checks
    # Failed tests prevent AMI distribution
    image_tests_enabled = true
    
    # Test timeout in minutes
    # Allows sufficient time for instance boot, test execution, and cleanup
    # 60 minutes is generous - typical tests complete in 5-15 minutes
    timeout_minutes = 60
  }

  tags = {
    ManagedBy = "AWSImageBuilder"
  }
}

################################################################################
# Pipeline Execution Workflow
################################################################################
# When the pipeline executes (scheduled or manual), it:
# 1. Launches temporary EC2 instance in private subnet (infra config)
# 2. Installs Systems Manager agent and connects to Image Builder service
# 3. Executes components in order (os_tooling → custom_scripts)
# 4. Runs automated tests if enabled (validate AMI functionality)
# 5. Creates AMI snapshot from the build instance
# 6. Applies tags from distribution configuration
# 7. Updates SSM Parameter with new AMI ID
# 8. Triggers EventBridge state change event (triggers Lambda)
# 9. Terminates build instance
# 10. Marks build as AVAILABLE (successful) or FAILED
#
# Total time: 15-45 minutes depending on instance type and component complexity
################################################################################