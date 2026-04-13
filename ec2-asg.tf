################################################################################
# EC2 Auto Scaling Group Configuration
################################################################################
# This file defines the Launch Template and Auto Scaling Group (ASG) that
# orchestrate EC2 instance deployment. The Launch Template defines the instance
# configuration, while the ASG manages the lifecycle and scaling behavior.
#
# Key Features:
# - Automatic AMI updates via Parameter Store reference
# - Encrypted EBS volumes with GP3 for cost-performance optimization
# - Multi-AZ deployment across private subnets
# - Scalable design supporting demand-based or scheduled scaling
#
# The Launch Template is updated automatically by Image Builder's native
# launch_template_configuration when new AMIs become available.
################################################################################

################################################################################
# Launch Template - EC2 Instance Configuration
################################################################################
# The Launch Template is a reusable configuration that defines how EC2 instances
# should be launched by the Auto Scaling Group. It acts as a blueprint containing
# all instance specifications: AMI, instance type, storage, networking, and IAM.
#
# Launch Template Benefits:
# - Versioning: Supports rollback to previous configurations
# - Immutability: Each change creates a new version (audit trail)
# - Reusability: Can be shared across multiple ASGs or used for manual launches
# - Flexibility: Auto Scaling can use specific versions or always-latest
################################################################################

resource "aws_launch_template" "custom_lt" {
  # Name prefix with auto-generated suffix
  # Terraform creates unique names like "custom-lt-20240115123456"
  # This allows recreation without conflicts during updates
  # Note: Cannot be changed without destroying and recreating the template
  name_prefix = "custom-lt-"
  
  # AMI ID dynamically retrieved from Parameter Store
  # This reference is evaluated during Terraform apply, not during plan
  # When Image Builder creates a new AMI, it updates the SSM parameter,
  # but the Launch Template retains the AMI ID from initial creation.
  # Image Builder's native launch_template_configuration handles creating
  # new LT versions with updated AMIs during distribution.
  #
  # Initial deployment: Uses base Amazon Linux 2023 AMI
  # After first Image Builder run: Parameter updates, native LT distribution creates new LT version
  # Subsequent scaling events: ASG uses "$Latest" version with updated AMI
  image_id = aws_ssm_parameter.custom_built_custom_id.value
  
  # Instance type from variables - allows environment-specific sizing
  # Examples: t4g.micro (dev), t4g.small (staging), t4g.large (prod)
  # Matches the architecture of the AMI (ARM64 for t4g, x86_64 for t3)
  instance_type = var.instance_type
  
  # Security group controls network access for instances
  # References the security group defined in security-group.tf
  # Allows HTTPS egress for package downloads and AWS API calls
  # Instances inherit all security group rules automatically
  vpc_security_group_ids = [aws_security_group.MyExampleSG.id]

  # IAM Instance Profile for AWS service access
  # Attaches an IAM role to instances, granting them permissions to:
  # - Access AWS services (S3, DynamoDB, CloudWatch, etc.)
  # - Authenticate without storing credentials on the instance
  # - Assume role permissions defined in iam.tf
  #
  # The instance profile is a wrapper that allows EC2 to assume the IAM role
  # Current configuration has minimal permissions - extend based on application needs
  iam_instance_profile {
    name = aws_iam_instance_profile.scanbox.name
  }

  # Block Device Mapping - EBS Volume Configuration
  # Defines storage configuration for the root volume
  block_device_mappings {
    # Device name for the root volume (Amazon Linux 2023 standard)
    # /dev/xvda is the root device for most Linux AMIs on AWS
    # This maps to the first volume that the OS boots from
    device_name = "/dev/xvda"
    
    ebs {
      # Volume size in GB - 20 GB is sufficient for most workloads
      # Increase for applications requiring more local storage
      # Base Amazon Linux 2023 AMI is ~2-3 GB, leaving ~17 GB for applications
      volume_size = 20
      
      # GP3 volume type - latest generation general-purpose SSD
      # GP3 advantages over GP2:
      # - 20% cheaper for same storage
      # - Baseline 3,000 IOPS and 125 MB/s (independent of volume size)
      # - Scalable performance up to 16,000 IOPS and 1,000 MB/s
      # - Predictable performance regardless of volume size
      #
      # Alternative types:
      # - gp2: Previous generation, IOPS scales with size (3 IOPS/GB)
      # - io1/io2: Provisioned IOPS for high-performance databases
      # - st1: Throughput-optimized HDD for big data workloads
      # - sc1: Cold HDD for infrequent access
      volume_type = "gp3"
      
      # Encryption at rest using AWS-managed keys
      # Protects data on the EBS volume from unauthorized access
      # Uses AWS-managed default EBS encryption key (aws/ebs)
      # For additional control, specify kms_key_id with a customer-managed CMK
      #
      # Encryption benefits:
      # - No performance impact (hardware-accelerated)
      # - No additional cost
      # - Protects against physical drive theft
      # - Meets compliance requirements (HIPAA, PCI-DSS, etc.)
      encrypted = true
    }
  }

  # Tag Specifications - Apply tags to instances and volumes
  # Tags are applied at launch time to all instances created from this template
  # Separate tag_specifications blocks can be added for volumes, network interfaces, etc.
  tag_specifications {
    # Resource type to tag - applies to the EC2 instance itself
    # Other options: "volume", "network-interface", "spot-instances-request"
    resource_type = "instance"
    
    tags = {
      # Human-readable instance name visible in EC2 Console
      # Helps identify instances in AWS Console, CloudWatch, and monitoring tools
      Name = "AnExampleInstance"
      
      # Project identifier for cost allocation and resource grouping
      # Matches the project variable for consistency across all resources
      # Used by AWS Cost Explorer to aggregate costs by project
      Project = var.project
      
      # Note: Default tags from the AWS provider (main.tf) are automatically
      # applied in addition to these tags, providing consistent tagging
      # across all infrastructure resources
    }
  }
  
  # Launch Template Lifecycle Management
  # Ignore changes to default_version because Image Builder creates new LT
  # versions outside of Terraform via the native launch_template_configuration
  # block and sets the default. Without this, terraform plan would show drift
  # after every Image Builder pipeline run.
  # Note: latest_version is a computed-only attribute (provider-decided) and
  # does not need to be in ignore_changes.
  lifecycle {
    ignore_changes = [default_version]
  }

  # Additional Launch Template features available but not configured:
  # - user_data: Bootstrap scripts run at instance launch
  # - metadata_options: IMDSv2 configuration for enhanced security
  # - monitoring: Detailed CloudWatch monitoring (1-minute intervals)
  # - placement: Placement group, tenancy, availability zone
  # - network_interfaces: Advanced networking configuration
  # - capacity_reservation: Capacity reservations for guaranteed capacity
  # - license_specification: License Manager integration
  # - hibernation_options: Instance hibernation support
}


################################################################################
# Auto Scaling Group - Dynamic Instance Management
################################################################################
# The Auto Scaling Group (ASG) manages a fleet of EC2 instances based on the
# Launch Template configuration. It automatically maintains desired capacity,
# replaces unhealthy instances, and can scale based on demand or schedule.
#
# Current Configuration:
# - Capacity: 0-1 instances (manual scaling required)
# - Multi-AZ: Distributes instances across private subnets in multiple AZs
# - Health Checks: EC2-based health monitoring
#
# Scaling can be added later:
# - Target Tracking: Scale based on CPU, memory, or custom metrics
# - Step Scaling: Scale in steps based on CloudWatch alarms
# - Scheduled Scaling: Scale at specific times or dates
# - Predictive Scaling: ML-based scaling predictions
################################################################################

resource "aws_autoscaling_group" "custom_asg" {
  # ASG name - used for identification in AWS Console and APIs
  # Unlike Launch Template, this has a fixed name (no prefix)
  # Changing the name requires destroying and recreating the ASG
  name = "custom-asg"
  
  # Desired Capacity: 0 instances
  # The ASG will not launch any instances by default
  # This is intentional for cost control during demonstration/testing
  # 
  # To launch instances:
  # 1. Update desired_capacity to desired number (e.g., 1, 2, 5)
  # 2. Run terraform apply
  # 3. ASG will launch instances using the Launch Template
  #
  # Alternatively, modify via AWS Console or CLI without Terraform changes
  desired_capacity = 0
  
  # Maximum Capacity: 1 instance
  # Limits the maximum number of instances the ASG can create
  # Prevents unexpected scaling costs during autoscaling operations
  # 
  # For production use cases, increase based on:
  # - Expected traffic patterns
  # - Performance requirements
  # - Budget constraints
  # - EC2 service quotas (soft limits)
  #
  # Example values:
  # - Development: 1-2 instances (minimal cost)
  # - Staging: 2-5 instances (moderate load testing)
  # - Production: 5-50+ instances (based on capacity planning)
  max_size = 1
  
  # Minimum Capacity: 0 instances
  # The ASG can scale down to zero instances when not needed
  # This enables complete cost savings when workload is idle
  #
  # For production high-availability:
  # - Set min_size to at least 2 (survive single instance failure)
  # - Set min_size across multiple AZs (survive AZ failure)
  # - Consider warm pool for faster scale-out response
  min_size = 0
  
  # VPC Subnets for Instance Placement
  # ASG launches instances in these subnets, automatically distributing
  # across availability zones for high availability and fault tolerance
  #
  # Current configuration: Private subnets in 2 AZs
  # - Instances have no direct internet access (enhanced security)
  # - Outbound internet via NAT Gateway (AWS API calls, package downloads)
  # - Protected from direct inbound internet traffic
  #
  # Multi-AZ benefits:
  # - Survive availability zone failures (power, networking, natural disasters)
  # - Lower latency by placing instances closer to users in different AZs
  # - Meet AWS Well-Architected reliability requirements
  #
  # The module.vpc.private_subnets reference returns a list of subnet IDs
  # defined in vpc.tf (e.g., ["subnet-abc123", "subnet-def456"])
  vpc_zone_identifier = module.vpc.private_subnets
  
  # Health Check Configuration
  # ASG monitors instance health and replaces unhealthy instances automatically
  #
  # Health Check Type: "EC2"
  # - EC2 health checks monitor instance status checks (system and instance)
  # - Marks instances unhealthy if status checks fail
  # - Does not monitor application health (use "ELB" type with load balancers)
  #
  # EC2 Status Checks:
  # - System Status: Physical host, network, power (AWS infrastructure)
  # - Instance Status: OS, kernel, network config (guest operating system)
  #
  # Alternative: "ELB" health check type
  # - Requires Application/Network Load Balancer
  # - Monitors application-level health (HTTP response codes)
  # - More sophisticated but requires additional infrastructure
  health_check_type = "EC2"
  
  # Health Check Grace Period: 300 seconds (5 minutes)
  # Time to wait after instance launch before starting health checks
  # This prevents ASG from terminating instances during startup
  #
  # Considerations:
  # - Application startup time: OS boot + application initialization
  # - Amazon Linux 2023 typically boots in 30-60 seconds
  # - Add time for user_data scripts, package downloads, app startup
  # - Too short: Instances terminated before fully starting
  # - Too long: Slow detection of genuinely failed instances
  #
  # Recommended values:
  # - Simple applications: 120-300 seconds (2-5 minutes)
  # - Complex applications: 300-600 seconds (5-10 minutes)
  # - Containerized apps: 180-360 seconds (3-6 minutes)
  health_check_grace_period = 300

  # Launch Template Configuration
  # Specifies which Launch Template and version the ASG should use
  launch_template {
    # Launch Template ID reference from the resource defined above
    # This links the ASG to the Launch Template configuration
    id = aws_launch_template.custom_lt.id
    
    # Version: "$Latest"
    # AWS special variable that always resolves to the most recent version
    # This is critical for automatic AMI updates:
    #
    # Workflow:
    # 1. Image Builder creates new AMI → updates SSM parameter
    # 2. Image Builder's native LT distribution creates new Launch Template version
    # 3. New version is set as default (set_default_version = true)
    # 4. ASG configured with "$Latest" automatically uses new version
    # 5. New scale-out events launch instances with updated AMI
    # 6. Existing instances remain running (no disruption)
    #
    # Alternative version options:
    # - "$Default": Use the version marked as default (recommended)
    # - "$Latest": Always use the newest version (current configuration)
    # - Specific number: Use a fixed version (e.g., "5") - no automatic updates
    #
    # Note: Changing the version doesn't affect running instances.
    # To update running instances, use instance refresh or terminate manually.
    version = "$Latest"
  }

  # ASG-Level Tags
  # These tags are applied to the ASG resource itself
  # Use tag_specifications in Launch Template to tag instances
  tag {
    key   = "Project"
    value = var.project
    
    # Propagate to Instances: true
    # This tag is copied to every EC2 instance launched by the ASG
    # Enables consistent tagging for cost allocation and resource management
    #
    # Tags with propagate_at_launch = true appear on:
    # - EC2 instances
    # - EBS volumes attached to instances (if configured)
    #
    # Tags with propagate_at_launch = false appear only on:
    # - The ASG resource itself
    propagate_at_launch = true
  }
  
  # Additional tags can be added here following the same pattern
  # Example:
  # tag {
  #   key                 = "Environment"
  #   value               = "Production"
  #   propagate_at_launch = true
  # }
  
  # Auto Scaling Group Features Available (Not Currently Configured)
  #
  # 1. SCALING POLICIES
  #    - Target Tracking: Maintain specific metric (CPU, requests/target)
  #    - Step Scaling: Scale based on CloudWatch alarm thresholds
  #    - Simple Scaling: Legacy scaling based on single threshold
  #
  # 2. SCHEDULED ACTIONS
  #    - Scale at specific times (business hours, peak periods)
  #    - Recurring schedules (daily, weekly)
  #    - One-time scheduled scaling events
  #
  # 3. INSTANCE REFRESH
  #    - Rolling replacement of instances
  #    - Gradual deployment of new AMIs or configurations
  #    - Configurable rollout speed and health checks
  #
  # 4. WARM POOL
  #    - Pre-initialized instances for faster scale-out
  #    - Reduces time to serve traffic during traffic spikes
  #    - Cost-effective with hibernated or stopped instances
  #
  # 5. MIXED INSTANCES POLICY
  #    - Combine multiple instance types for cost optimization
  #    - Use Spot instances for cost savings (up to 90% discount)
  #    - Automatic fallback to On-Demand if Spot unavailable
  #
  # 6. LIFECYCLE HOOKS
  #    - Custom actions during instance launch/termination
  #    - Pause lifecycle for registration, data backup, deregistration
  #    - Integrate with Lambda for custom automation
  #
  # 7. METRICS COLLECTION
  #    - Enable group metrics for advanced monitoring
  #    - Track ASG-level metrics (GroupDesiredCapacity, GroupInServiceInstances)
  #    - Enhanced CloudWatch integration
  #
  # 8. LOAD BALANCER INTEGRATION
  #    - Attach Application/Network Load Balancer
  #    - Automatic instance registration/deregistration
  #    - ELB health checks for application-level monitoring
  #
  # 9. PLACEMENT STRATEGIES
  #    - Placement groups for low-latency networking
  #    - Partition placement for fault isolation
  #    - Spread placement for maximum distribution
  #
  # 10. TERMINATION POLICIES
  #     - Control which instances are terminated first during scale-in
  #     - Options: OldestInstance, NewestInstance, OldestLaunchTemplate, etc.
  #     - Default: Balanced across AZs, then oldest launch configuration
}

################################################################################
# Next Steps for Production Use
################################################################################
#
# This configuration provides a foundation for autoscaling infrastructure.
# For production deployments, consider adding:
#
# 1. APPLICATION LOAD BALANCER
#    - Distribute traffic across multiple instances
#    - SSL/TLS termination
#    - Path-based routing
#    - Health checks and automatic failover
#
# 2. TARGET TRACKING SCALING
#    - Automatically scale based on CPU utilization (target: 70%)
#    - Scale based on custom CloudWatch metrics
#    - Predictable scaling behavior
#
# 3. INSTANCE REFRESH
#    - Automated rolling replacement after AMI updates
#    - Gradual rollout with health checks
#    - Automatic rollback on failures
#
# 4. CLOUDWATCH ALARMS
#    - Monitor ASG health and scaling events
#    - Alert on scaling failures
#    - Track instance launch/termination
#
# 5. MULTI-REGION DEPLOYMENT
#    - Disaster recovery across regions
#    - Global load balancing with Route53
#    - Cross-region AMI copying
#
# 6. ENHANCED SECURITY
#    - IMDSv2 enforcement (metadata_options in Launch Template)
#    - Encrypted AMIs with customer-managed keys
#    - VPC endpoints to eliminate NAT Gateway dependency
#    - Security group ingress restrictions
#
################################################################################
