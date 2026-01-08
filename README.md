# AWS Autoscaling with EC2 Image Builder

[![Terraform](https://img.shields.io/badge/Terraform-1.11+-blue.svg)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-Multiple%20Services-orange.svg)](https://aws.amazon.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

> **An educational infrastructure project demonstrating event-driven autoscaling patterns using EC2 Image Builder, Lambda automation, and EventBridge integration.**

This project showcases modern AWS infrastructure automation patterns through a fully automated AMI lifecycle management system. Learn how to build event-driven architectures that eliminate manual operations while maintaining security and cost efficiency.


## Table of Contents

### Getting Started
- [Learning Objectives](#learning-objectives) - What you'll learn from this project
- [Architecture Overview](#architecture-overview) - High-level system design
- [Prerequisites](#prerequisites) - Required tools and permissions
- [Deployment Instructions](#deployment-instructions) - Step-by-step deployment guide

### Understanding the Architecture
- [AWS Services Used](#aws-services-used) - Detailed service explanations
- [How It Works](#how-it-works) - Complete workflow walkthrough
- [File Structure & Purpose](#file-structure--purpose) - Terraform file documentation
- [Event-Driven Automation Workflow](#event-driven-automation-workflow) - Technical deep dive


### Resources & References
- [Additional Resources](#additional-resources) - Documentation and learning materials
  - [AWS Documentation](#aws-documentation)
  - [Best Practices Guides](#best-practices-guides)
  - [Terraform Resources](#terraform-resources)
  - [Tools and Utilities](#tools-and-utilities)

---

> **Quick Start**: New to this project? Start with [Prerequisites](#prerequisites) → [Deployment Instructions](#deployment-instructions) → [Verification](#step-6-verify-deployment)

## Learning Objectives

By exploring and deploying this project, you will learn:

### Infrastructure Automation Concepts
- **Event-Driven Architecture**: Understand how AWS services communicate through EventBridge to create automated workflows
- **Infrastructure as Code**: Gain experience of Terraform patterns for a simple, multi-service AWS deployment
- **Immutable Infrastructure**: Learn the benefits and implementation of treating infrastructure as disposable and reproducible

### AWS Service Integration Patterns
- **EC2 Image Builder**: Automate the creation of hardened, custom AMIs with scheduled builds and testing
- **Auto Scaling Groups**: Implement dynamic scaling with custom launch templates that automatically use the latest AMIs
- **Lambda Automation**: Build serverless functions that respond to AWS events and update infrastructure components
- **EventBridge Integration**: Create event-driven workflows that connect multiple AWS services seamlessly

### Security and Compliance
- **IAM Best Practices**: Implement least-privilege access patterns for cross-service communication
- **Encrypted Storage**: Configure encrypted EBS volumes and secure AMI distribution
- **VPC Security**: Design network isolation with proper subnet segmentation and security groups

### Operational Excellence
- **Automated Updates**: Eliminate manual AMI management through automated pipeline workflows
- **Monitoring and Logging**: Implement CloudWatch integration for pipeline visibility and troubleshooting
- **Scalable Patterns**: Design infrastructure that can grow from development to production environments

## Architecture Overview

This project demonstrates a **modern, event-driven autoscaling pattern** that automatically maintains up-to-date, hardened AMIs in your Auto Scaling Groups. The architecture eliminates manual AMI management while ensuring your instances always run the latest, security-patched images.

### Core Architecture Pattern

```mermaid
graph TB
    A[EventBridge Schedule] -->|Weekly Trigger| B[Image Builder Pipeline]
    B -->|Build Complete| C[Custom AMI Created]
    C -->|State Change Event| D[EventBridge Rule]
    D -->|Trigger| E[Lambda Function]
    E -->|Update| F[Launch Template]
    F -->|New Version| G[Auto Scaling Group]
    G -->|Scale Events| H[EC2 Instances with Latest AMI]
    
    subgraph "Image Building"
        B
        C
    end
    
    subgraph "Event-Driven Updates"
        D
        E
        F
    end
    
    subgraph "Compute Layer"
        G
        H
    end
```

### Key Architectural Benefits

1. **Zero-Touch AMI Management**: Once deployed, the system automatically builds, tests, and deploys new AMIs without manual intervention
2. **Event-Driven Automation**: Uses AWS native event systems to create loosely coupled, resilient automation workflows  
3. **Immutable Infrastructure**: Promotes the practice of replacing rather than patching infrastructure components
4. **Scalable Foundation**: Provides a template that can be extended for complex, multi-environment deployments

## AWS Services Used

This architecture leverages multiple AWS services working together to create a fully automated, event-driven infrastructure pattern. Each service plays a specific role in the overall workflow.

### Core Compute Services

#### **[EC2 Image Builder](https://docs.aws.amazon.com/imagebuilder/)**
- **Role**: Automated AMI creation pipeline with built-in testing and validation
- **Key Components**:
  - **Image Recipe**: Defines the base AMI (Amazon Linux 2023) and custom components to install
  - **Infrastructure Configuration**: Specifies build environment (instance type, VPC, security groups)
  - **Distribution Configuration**: Manages AMI distribution across regions and accounts
  - **Pipeline**: Orchestrates the entire build process with scheduling capabilities
- **Automation**: Scheduled weekly builds (Tuesdays at 02:00 UTC) with automatic testing
- **Output**: Hardened, custom AMIs with consistent tooling and security configurations

#### **[Auto Scaling Groups (ASG)](https://docs.aws.amazon.com/autoscaling/)**
- **Role**: Dynamic instance management with automatic scaling based on demand
- **Integration**: Uses launch templates that automatically reference the latest AMI
- **Configuration**: Deployed across multiple AZs for high availability
- **Scaling**: Currently configured for 0-1 instances (can be adjusted for production workloads)

#### **[Launch Templates](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-launch-templates.html)**
- **Role**: Versioned instance configuration management
- **Key Features**:
  - References AMI ID from Systems Manager Parameter Store
  - Defines instance type, security groups, and IAM instance profile
  - Configures encrypted EBS volumes (20GB GP3)
  - Supports automatic versioning for seamless updates
- **Automation**: Lambda function creates new versions when AMIs are updated

### Event-Driven Automation Services

#### **[Amazon EventBridge](https://docs.aws.amazon.com/eventbridge/)**
- **Role**: Event-driven service integration and workflow orchestration
- **Key Functions**:
  - **Scheduling**: Triggers Image Builder pipeline on a weekly schedule
  - **Event Routing**: Captures Image Builder state change events and routes them to Lambda
  - **Event Pattern Matching**: Filters for "AVAILABLE" status events from successful builds
- **Integration Pattern**: Decouples services through event-driven communication

#### **[AWS Lambda](https://docs.aws.amazon.com/lambda/)**
- **Role**: Serverless automation for infrastructure updates
- **Function**: `ltupdater` - Updates launch templates when new AMIs are available
- **Key Capabilities**:
  - Retrieves latest AMI ID from Systems Manager Parameter Store
  - Creates new launch template versions with updated AMI
  - Sets new version as default for Auto Scaling Group
  - Runs in VPC for secure access to private resources
- **Runtime**: Python 3.12 with 60-second timeout

#### **[Systems Manager Parameter Store](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html)**
- **Role**: Secure storage and retrieval of AMI identifiers
- **Parameter**: `/imagebuilder/{project}/custom_id` stores the latest AMI ID
- **Integration**: 
  - Updated automatically by Image Builder distribution configuration
  - Read by Lambda function for launch template updates
  - Referenced by launch template for AMI selection
- **Data Type**: `aws:ec2:image` for AMI-specific validation

### Security & Networking Infrastructure

#### **[Virtual Private Cloud (VPC)](https://docs.aws.amazon.com/vpc/)**

- **Role**: Isolated network environment for all resources
- **Architecture**: 
  - **CIDR Block**: 11.0.0.0/16 (private address space)
  - **Availability Zones**: Spans 2 AZs for high availability
  - **Public Subnets**: 11.0.1.0/24, 11.0.2.0/24 (for NAT Gateway)
  - **Private Subnets**: 11.0.101.0/24, 11.0.102.0/24 (for compute resources)
- **Connectivity**: Single NAT Gateway for outbound internet access from private subnets
- **Improvement Idea**: The focus of this lab is not on VPC customisation, hence the simple approach to VPC setup here. For better control over VPC customisation, and greater reusability, consider replacing statically defined values with variables.

#### **[Security Groups](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-security-groups.html)**
- **Role**: Network-level access control and traffic filtering
- **Configurations**:
  - **Main Security Group**: HTTPS (443) ingress/egress for EC2 instances
  - **Lambda Security Group**: HTTPS (443) egress only for AWS API calls
- **Security Principle**: Minimal required access with explicit allow rules

#### **[Identity and Access Management (IAM)](https://docs.aws.amazon.com/IAM/)**
- **Role**: Least-privilege access control for cross-service communication
- **Key Roles**:
  - **Image Builder Instance Profile**: Permissions for build process and S3 access
  - **Lambda Execution Role**: EC2, SSM, and VPC permissions for launch template updates
  - **EC2 Instance Profile**: Runtime permissions for deployed instances
- **Security Pattern**: Service-specific roles with minimal required permissions

### Supporting Services

#### **[Elastic Block Store (EBS)](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AmazonEBS.html)**

- **Role**: Encrypted storage for EC2 instances
- **Configuration**: 20GB GP3 volumes with encryption at rest
- **Integration**: Configured in launch template for consistent storage setup
- **Improvement Idea**: This lab utilises default EBS encryption. In a real world scenario, consider using [AWS Key Management Service - Customer Managed Keys (KMS CMK)](https://docs.aws.amazon.com/kms/latest/developerguide/concepts.html). KMS CMK allows you to control the key policy, who can decrypt/encrypt using that key etc - which allows for better and more fine grained access control to encrypted volumes than the default key, but costs a small amount more. This will become mandatory if you want to share AMI's across Regions or AWS Accounts.

#### **[CloudWatch](https://docs.aws.amazon.com/cloudwatch/)**
- **Role**: Configuring rules for EventBridge
- **Integration**: EventBridge rules use CloudWatch Events for state change detection
- **Observability**: Provides logs and metrics for troubleshooting automation workflows

## How It Works

This section provides a detailed walkthrough of the event-driven automation workflow, explaining how each AWS service contributes to the overall pattern.

### 1. Scheduled AMI Creation Pipeline

#### **Pipeline Initialization**
```hcl
resource "aws_imagebuilder_image_pipeline" "pipeline" {
  name                             = "${var.project}-pipeline"
  status                           = "ENABLED"
  enhanced_image_metadata_enabled  = true

  schedule {
    schedule_expression                = "cron(0 2 ? * TUE *)"
    pipeline_execution_start_condition = "EXPRESSION_MATCH_ONLY"
  }
}
```

- **EventBridge Schedule**: Triggers the Image Builder pipeline weekly (Tuesdays at 02:00 UTC)
- **Schedule Expression**: `cron(0 2 ? * TUE *)` ensures consistent, predictable builds
- **Pipeline Status**: Enabled with enhanced metadata collection for detailed tracking
- **Execution Condition**: `EXPRESSION_MATCH_ONLY` prevents manual triggers from interfering with scheduled builds

#### **Image Building Process**
1. **Infrastructure Provisioning**: Image Builder launches a temporary EC2 instance in the private subnet
2. **Base Image Selection**: Starts with the latest Amazon Linux 2023 AMI from AWS
3. **Component Installation**: Applies custom components in sequence:
   - **OS Tooling Component**: Installs essential system tools and security hardening
   - **Custom Scripts Component**: Downloads and configures project-specific tooling
4. **Image Testing**: Built-in tests validate the AMI functionality (60-minute timeout)
5. **AMI Creation**: Successful builds create a new AMI with standardized naming: `{project}-{buildDate}`

#### **Distribution and Storage**
- **AMI Distribution**: New AMI is distributed with consistent tags (OS, Hardened, Name)
- **Parameter Store Update**: AMI ID is automatically stored in `/imagebuilder/{project}/custom_id`
- **Cleanup**: Temporary build instance is terminated after successful completion

### 2. Event-Driven Launch Template Updates

#### **Event Detection and Routing**
```json
{
  "source": ["aws.imagebuilder"],
  "detail-type": ["EC2 Image Builder Image State Change"],
  "detail": {
    "state": {
      "status": ["AVAILABLE"]
    }
  }
}
```

- **EventBridge Rule**: Monitors for Image Builder state change events
- **Event Filtering**: Only processes events with "AVAILABLE" status (successful builds)
- **Lambda Trigger**: Matching events automatically invoke the `ltupdater` Lambda function

#### **Automated Launch Template Updates**
The Lambda function performs the following operations:

1. **AMI ID Retrieval**: Reads the latest AMI ID from Systems Manager Parameter Store
2. **Launch Template Versioning**: Creates a new launch template version with:
   - Updated AMI ID from the latest build
   - Consistent instance configuration (type, security groups, IAM profile)
   - Encrypted EBS volume configuration (20GB GP3)
3. **Default Version Update**: Sets the new version as the default for the Auto Scaling Group
4. **Error Handling**: Includes comprehensive error handling and logging for troubleshooting

#### **Lambda Function Environment**
- **Runtime**: Python 3.12 with optimized performance
- **VPC Integration**: Runs within private subnets for secure AWS API access
- **Environment Variables**: Configurable parameters for launch template ID, instance type, and security groups
- **Timeout**: 60-second execution limit for reliable completion

### 3. Automatic Instance Lifecycle Management

#### **Auto Scaling Group Integration**
```hcl
launch_template {
  id      = aws_launch_template.custom_lt.id
  version = "$Latest"
}
```

- **Dynamic Version Reference**: ASG configured with `$Latest` ensures automatic adoption of new launch template versions
- **Zero-Configuration Updates**: No ASG modification required when Lambda updates launch template default version
- **Immediate Effect**: New scaling events automatically use the updated AMI without manual intervention
- **Multi-AZ Deployment**: Instances launched across private subnets in multiple availability zones for resilience
- **Consistent Configuration**: All instances maintain identical security groups, IAM profiles, and EBS encryption settings

#### **Instance Refresh Capabilities**
- **Manual Refresh**: Existing instances can be refreshed using ASG instance refresh features
- **Rolling Updates**: Supports gradual replacement of existing instances with new AMI
- **Zero-Downtime**: Maintains service availability during instance updates (when properly configured)

#### **Scaling Behavior**
- **Current Configuration**: 0-1 instances (suitable for development/testing)
- **Production Scaling**: Can be adjusted for higher capacity and automatic scaling policies
- **Health Checks**: EC2 health checks ensure only healthy instances remain in service

### 4. Security and Network Isolation

#### **Network Architecture**
- **VPC Isolation**: All resources operate within a dedicated VPC (11.0.0.0/16)
- **Subnet Strategy**: 
  - **Private Subnets**: Host compute resources (Image Builder, Lambda, EC2 instances)
  - **Public Subnets**: Contain NAT Gateway for controlled outbound internet access
- **Internet Connectivity**: Single NAT Gateway provides cost-effective outbound access

#### **Security Controls**
- **Security Groups**: Implement network-level access control
  - **Instance Security Group**: HTTPS (443) for AWS API communication
  - **Lambda Security Group**: Outbound HTTPS only for service calls
- **IAM Roles**: Enforce least-privilege access patterns
  - **Service-Specific Permissions**: Each service has only required permissions
  - **Cross-Service Access**: Secure communication between Lambda, SSM, and EC2 services

#### **Data Protection**
- **Encryption at Rest**: All EBS volumes use AWS-managed encryption
- **Secure Parameter Storage**: AMI IDs stored securely in Systems Manager Parameter Store
- **Network Encryption**: All AWS API calls use TLS encryption in transit

### 5. Event-Driven Architecture Benefits

#### **Loose Coupling**
- **Service Independence**: Each service operates independently with event-based communication
- **Failure Isolation**: Issues in one component don't cascade to others
- **Scalability**: Individual services can be scaled based on specific requirements

#### **Automation Reliability**
- **Consistent Execution**: Scheduled builds ensure regular AMI updates
- **Automatic Recovery**: Failed builds don't affect existing infrastructure
- **Audit Trail**: EventBridge and CloudWatch provide complete workflow visibility

#### **Operational Excellence**
- **Zero-Touch Operations**: No manual intervention required for AMI lifecycle management
- **Predictable Updates**: Scheduled builds provide consistent, testable update cycles
- **Infrastructure as Code**: Complete automation enables version control and reproducible deployments

This comprehensive automation pattern eliminates manual AMI management while ensuring your infrastructure remains current with security patches and organizational standards.

## Prerequisites

Before deploying this infrastructure, ensure you have the following tools and permissions configured:

### Required Tools and Versions

#### **Terraform**
- **Version**: >= 1.11.0 (as specified in `main.tf`)
- **Installation**: Download from [terraform.io](https://www.terraform.io/downloads.html)
- **Verification**: Run `terraform version` to confirm installation

#### **AWS CLI**
- **Version**: >= 2.0 (recommended for latest features)
- **Installation**: Follow [AWS CLI installation guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- **Configuration**: Run `aws configure` to set up credentials and default region

#### **Git** (Optional but Recommended)
- **Purpose**: Version control and project cloning
- **Installation**: Download from [git-scm.com](https://git-scm.com/downloads)

### AWS Account Requirements

#### **AWS Account Access**
- **Administrative Privileges**: Required for creating IAM roles, VPC resources, and AWS services
- **Account Limits**: Ensure sufficient service limits for:
  - VPC (1 additional VPC)
  - EC2 instances (for Image Builder and Auto Scaling)
  - Lambda functions (1 function)
  - EventBridge rules (2 rules)

#### **AWS Credentials Configuration**
Choose one of the following authentication methods:

**Option 1: AWS CLI Profiles**
```bash
aws configure --profile your-profile-name
# Enter: Access Key ID, Secret Access Key, Default region, Output format
```

**Option 2: Environment Variables**
```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="eu-west-1"
```

**Option 3: IAM Roles (for EC2/Lambda execution)**
- Attach appropriate IAM role to your execution environment
- Ensure role has necessary permissions listed below

#### **Required AWS Permissions**
Your AWS credentials must have permissions for the following services:
- **EC2**: Full access for instances, launch templates, Auto Scaling Groups
- **VPC**: Full access for VPC, subnets, security groups, NAT Gateway
- **IAM**: Create and manage roles, policies, and instance profiles
- **Image Builder**: Full access for pipelines, recipes, components
- **Lambda**: Create and manage functions, permissions
- **EventBridge**: Create and manage rules, targets
- **Systems Manager**: Parameter Store read/write access
- **CloudWatch**: Logs and events access

**Minimum IAM Policy Example:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "iam:*",
        "imagebuilder:*",
        "lambda:*",
        "events:*",
        "ssm:*",
        "logs:*"
      ],
      "Resource": "*"
    }
  ]
}
```

### Regional Considerations

#### **Supported Regions**
- **Default Region**: eu-west-1 (Ireland)
- **Alternative Regions**: Any AWS region supporting all required services
- **Service Availability**: Verify that EC2 Image Builder is available in your chosen region

#### **Graviton Instance Support**
- **Instance Types**: t4g family (ARM64 architecture)
- **Regional Availability**: Ensure Graviton instances are available in your deployment region
- **Alternative**: Modify `build_instance_types` variable for x86 instances if needed

### Network Requirements

#### **Internet Connectivity**
- **Outbound HTTPS**: Required for downloading packages and AWS API calls
- **NAT Gateway**: Automatically provisioned for private subnet internet access
- **No Inbound Access**: Architecture doesn't require inbound internet connectivity

#### **IP Address Planning**
- **VPC CIDR**: 11.0.0.0/16 (default, configurable)
- **Subnet Allocation**: 
  - Public: 11.0.1.0/24, 11.0.2.0/24
  - Private: 11.0.101.0/24, 11.0.102.0/24
- **Conflict Check**: Ensure CIDR doesn't conflict with existing VPCs

### Cost Considerations

#### **Estimated Monthly Costs** (eu-west-1 region)
- **VPC Components**: ~$45/month (NAT Gateway primary cost)
- **EC2 Instances**: Variable based on Auto Scaling Group usage
- **Image Builder**: ~$2-5/month (weekly builds, t4g.small instances)
- **Lambda**: <$1/month (minimal execution time)
- **Other Services**: <$5/month (EventBridge, Parameter Store, CloudWatch)

**Total Estimated Cost**: $50-60/month for development/testing workloads (or $1-2/day whilst testing)

#### **Cost Optimization Tips**
- **Clean up**: Most importantly - Delete the resources for the lab when you've finished to stop costs accumulating. 
- **Instance Types**: t4g.small provides good balance of cost and performance
- **Build Frequency**: Weekly builds balance security with cost
- **Auto Scaling**: Set appropriate min/max values for your workload

## Deployment Instructions

Follow these step-by-step instructions to deploy the autoscaling with Image Builder infrastructure:

### Step 1: Project Setup

#### **Clone or Download Project**
```bash
# Clone from repository (if available)
git clone https://github.com/jmcmillan1873/autoscaling-with-imagebuilder.git
cd autoscaling-with-imagebuilder
```

#### **Verify Project Structure**
Confirm you have all required files:
```bash
ls -la *.tf
# Expected files:
# main.tf, variables.tf, data.tf, locals.tf
# vpc.tf, security-group.tf, iam.tf
# imagebuilder.tf, lambda.tf, eventbridge.tf
# ec2-asg.tf, ssm.tf
```

### Step 2: Configure Variables

#### **Create terraform.tfvars File**
Create a `terraform.tfvars` file to customize your deployment:

```hcl
# terraform.tfvars
region           = "eu-west-1"             # Change to your preferred region
project          = "MyAutoscalingProject"  # Customize project name
instance_type    = "t4g.small"             # Adjust instance size as needed
ami_retain_count = 5                       # Number of AMIs to keep when housekeeping. 

# Customize default tags
default_tags = {
  Owner       = "YourName"
  Project     = "MyAutoscalingProject"
  Environment = "Development"  # or "Production", "Staging"
}

# Optional: Customize build instance types
build_instance_types = ["t4g.small", "t4g.medium"]
```

#### **Variable Configuration Options**

**Region Selection:**
- Select the region you'd like to deploy to. 
- Defaults to `eu-west-1`

**Project Naming:**
- Use alphanumeric characters and hyphens only
- Keep under 20 characters for resource name limits
- Choose descriptive names for easy identification

**Instance Type Selection:**
- The lab uses the Graviton t4g family. Feel free to change this, but make correct the code to accommodate (hint - look for `arm64` and change that to your preferred architecture type)

**Retain AMIs / Housekeeping**
- The `amicleaner` Lambda function deletes old AMIs and Snapshots, it will preserve as many images as is configured by `ami_retain_count`.

### Step 3: Initialize Terraform

#### **Initialize Terraform Backend**
```bash
terraform init
```

**Expected Output:**
```
Initializing the backend...
Initializing provider plugins...
- Finding hashicorp/aws versions matching "6.13.0"...
- Installing hashicorp/aws v6.13.0...
Terraform has been successfully initialized!
```

#### **Validate Configuration**
```bash
terraform validate
```

**Expected Output:**
```
Success! The configuration is valid.
```

### Step 4: Plan Deployment

#### **Review Deployment Plan**
```bash
terraform plan
```

### Step 5: Deploy Infrastructure

#### **Apply Terraform Configuration**
```bash
terraform apply
```

**Deployment Process:**
1. **Review Plan**: Terraform shows resources to be created
2. **Confirm Deployment**: Type `yes` when prompted
3. **Monitor Progress**: Watch resource creation (typically 5-10 minutes)
4. **Completion**: Note the outputs displayed at the end

**Expected Deployment Time:** 8-12 minutes

#### **Monitor Deployment Progress**
During deployment, you can monitor progress in the AWS Console:
- **VPC Console**: Watch VPC and subnet creation
- **EC2 Console**: Monitor security groups and launch template
- **Image Builder Console**: Verify pipeline creation
- **Lambda Console**: Confirm function deployment

### Step 6: Verify Deployment

#### **Check Terraform Outputs**
```bash
terraform output
```

**Expected Outputs:**
- VPC ID and subnet information
- Security group IDs
- Launch template ID
- Auto Scaling Group name
- Image Builder pipeline ARN

#### **Verify AWS Resources**

**1. VPC and Networking:**
```bash
# Check VPC creation
aws ec2 describe-vpcs --filters "Name=tag:Project,Values=YourProjectName"

# Verify subnets
aws ec2 describe-subnets --filters "Name=tag:Project,Values=YourProjectName"
```

**2. Image Builder Pipeline:**
```bash
# Check pipeline status
aws imagebuilder describe-image-pipelines --image-pipeline-arns $(terraform output -raw imagebuilder_pipeline_arn)
```

**3. Auto Scaling Group:**
```bash
# Verify ASG creation
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $(terraform output -raw asg_name)
```

**4. Lambda Function:**
```bash
# Check Lambda function
aws lambda get-function --function-name $(terraform output -raw lambda_function_name)
```

#### **Test Initial Functionality**

**1. Trigger Manual Image Build (Optional):**
```bash
# Start a manual pipeline execution
aws imagebuilder start-image-pipeline-execution --image-pipeline-arn $(terraform output -raw imagebuilder_pipeline_arn)
```

**2. Check Parameter Store:**
```bash
# Verify AMI parameter exists
aws ssm get-parameter --name "/imagebuilder/$(terraform output -raw project_name)/custom_id"
```

**3. Monitor CloudWatch Logs:**
```bash
# Check Lambda function logs (after first execution)
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/"
```

### Step 7: Post-Deployment Configuration

#### **Schedule Verification**
- **Image Builder Pipeline**: Automatically runs Tuesdays at 02:00 UTC
- **First Build**: May take 15-20 minutes to complete
- **EventBridge Rules**: Verify in AWS Console under EventBridge

#### **Security Review**
- **IAM Roles**: Review created roles and policies
- **Security Groups**: Verify network access rules
- **Encryption**: Confirm EBS volumes are encrypted

### Troubleshooting Deployment Issues

#### **Common Issues and Solutions**

**1. Insufficient Permissions:**
```bash
# Error: AccessDenied for specific service
# Solution: Review and update IAM permissions
aws sts get-caller-identity  # Verify current user/role
```

**2. Resource Limits:**
```bash
# Error: VPC limit exceeded
# Solution: Request limit increase or use existing VPC
aws ec2 describe-account-attributes --attribute-names supported-platforms
```

**3. Region Availability:**
```bash
# Error: Service not available in region
# Solution: Change region or verify service availability
aws ec2 describe-regions --all-regions
```

**4. Terraform State Issues:**
```bash
# Error: State lock or corruption
# Solution: Clear state lock or refresh state
terraform force-unlock <lock-id>  # Use with caution
terraform refresh
```

### Next Steps After Deployment

#### **Immediate Actions**
1. **Monitor First Build**: Watch the first Image Builder execution
2. **Review Costs**: Check AWS billing dashboard after 24 hours
3. **Test Scaling**: Manually adjust ASG capacity to test scaling

#### **Customization Opportunities**
1. **Modify Components**: Update Image Builder components for your needs
2. **Adjust Scaling**: Configure Auto Scaling policies for your workload
3. **Add Monitoring**: Implement additional CloudWatch metrics and alarms
4. **Upgrade Encryption**: Replace default EBS encryption with KMS CMK. 
5. **Add LifeCycle Policy**: Add a Lifecycle policy to EC2 Image Builder to delete older AMIs. e.g. *Retain the last 5 AMIs.* 

#### **Production Considerations**
1. **Backup Strategy**: Implement AMI and configuration backups
2. **Multi-Region**: Extend to multiple regions for disaster recovery (requires KMS CMK)
3. **Security Hardening**: Add additional security controls and monitoring

This comprehensive deployment guide ensures successful infrastructure deployment while providing troubleshooting guidance and next steps for customization.

## File Structure & Purpose

This section provides detailed documentation of each Terraform file, explaining their purpose, key resources, and relationships within the overall architecture.

### Core Configuration Files

#### **`main.tf`** - Provider and Terraform Configuration
**Purpose**: Defines Terraform and AWS provider requirements with default tagging strategy

**Key Resources**:
- **Terraform Block**: Specifies minimum Terraform version (>=1.11.0) and AWS provider version (6.0+)
- **AWS Provider**: Configures regional deployment with automatic default tagging
- **Default Tags**: Demonstrates applying consistent tags (Owner, Project, Environment) to all resources

**Configuration Notes**:
- Uses variable-driven region configuration for multi-region flexibility
- Implements organization-wide tagging standards through `var.default_tags`
- Provider version pinning ensures consistent deployments across environments

**Dependencies**: None (foundational configuration file)

---

#### **`variables.tf`** - Input Variable Definitions
**Purpose**: Centralizes all configurable parameters for the infrastructure deployment

**Key Variables**:
- **`region`**: AWS deployment region (default: eu-west-1)
- **`project`**: Project identifier used in resource naming and tagging
- **`instance_type`**: EC2 instance type for Auto Scaling Group (default: t4g.small)
- **`build_instance_types`**: Array of instance types for Image Builder (Graviton-based)
- **`default_tags`**: Standard tags applied to all resources
- **`ami_retain_count`**: The number of ImageBuilder produced AMI's to retain (Look at the `amicleaner` Lambda function to see selection criteria.)

**Configuration Notes**:
- Graviton-based instance types (t4g family) for cost optimization and performance
- Flexible build instance types support different workload requirements
- Consistent naming convention using project variable across all resources

**Dependencies**: Referenced by all other Terraform files for configuration values

---

#### **`locals.tf`** - Computed Local Values
**Purpose**: Defines dynamic values computed at runtime for use across the configuration

**Key Locals**:
- **`account_id`**: Current AWS account ID retrieved from caller identity
- **Dynamic References**: Enables account-specific resource ARN construction

**Configuration Notes**:
- Eliminates hardcoded account IDs for better portability
- Supports multi-account deployments with dynamic account resolution
- Used in IAM policies and resource ARNs requiring account-specific references

**Dependencies**: Uses `data.aws_caller_identity.current` from `data.tf`

---

#### **`data.tf`** - Data Sources and Policy Documents
**Purpose**: Retrieves external data and defines IAM policy documents for secure service communication

**Key Data Sources**:
- **`aws_caller_identity.current`**: Current AWS account information
- **`aws_ssm_parameter.al2023`**: Latest Amazon Linux 2023 ARM64 AMI ID
- **`aws_ami.al2023`**: AMI details for initial launch template configuration
- **`archive_file.ltupdater`**: Lambda deployment package creation

**IAM Policy Documents**:
- **`assume_lambda`**: Lambda service trust policy for function execution
- **`lambda_ltupdater_policy`**: Permissions for launch template updates and SSM access
- **`assume_ec2`**: EC2 and Image Builder service trust policy
- **`imagebuilder_permissions`**: Comprehensive Image Builder build permissions

**Configuration Notes**:
- Uses AWS-managed parameter for latest AMI discovery (`/aws/service/ami-amazon-linux-latest/`)
- Implements least-privilege IAM policies with specific resource access
- Supports ARM64 architecture alignment with Graviton instance types

**Dependencies**: None (provides foundational data for other resources)

---

### Networking Infrastructure

#### **`vpc.tf`** - Virtual Private Cloud Configuration
**Purpose**: Creates isolated network environment with public/private subnet architecture

**Key Resources**:
- **VPC Module**: Uses terraform-aws-modules/vpc for standardized VPC creation
- **Network Architecture**: 
  - CIDR: 11.0.0.0/16 (65,536 IP addresses)
  - Public Subnets: 11.0.1.0/24, 11.0.2.0/24 (for NAT Gateway)
  - Private Subnets: 11.0.101.0/24, 11.0.102.0/24 (for compute resources)
- **Connectivity**: Single NAT Gateway for cost-effective outbound internet access

**Configuration Notes**:
- Multi-AZ deployment across two availability zones for high availability
- Private subnets host all compute resources (EC2, Lambda, Image Builder)
- DNS resolution enabled for internal service discovery
- Single NAT Gateway reduces costs while maintaining outbound connectivity

**Dependencies**: Uses `var.region` and `var.default_tags` from variables

**Relationships**: Provides subnet IDs for security groups, Lambda, ASG, and Image Builder

---

#### **`security-group.tf`** - Network Access Control
**Purpose**: Implements network-level security controls with minimal required access

**Key Resources**:
- **`aws_security_group.MyExampleSG`**: Main security group for EC2 instances and Image Builder
  - **Ingress**: HTTPS (443) from anywhere (for AWS API access)
  - **Egress**: HTTPS (443) to anywhere (for software downloads and AWS APIs)
- **`aws_security_group.lambda`**: Lambda-specific security group
  - **Egress Only**: HTTPS (443) for AWS service communication

**Configuration Notes**:
- Follows principle of least privilege with minimal port exposure
- HTTPS-only communication ensures encrypted data in transit
- Separate security groups for different service types enable granular control
- No SSH access enforces immutable infrastructure practices

**Dependencies**: Requires VPC ID from `vpc.tf`

**Relationships**: Referenced by EC2 instances, Lambda functions, and Image Builder infrastructure

---

### Identity and Access Management

#### **`iam.tf`** - IAM Roles and Policies
**Purpose**: Implements least-privilege access control for cross-service communication

**Key Resources**:
- **`aws_iam_role.scanbox`**: EC2 instance role for deployed instances
- **`aws_iam_instance_profile.scanbox`**: Instance profile for EC2 role attachment
- **`aws_iam_role.imagebuilder_role`**: Image Builder service role with build permissions
- **`aws_iam_instance_profile.imagebuilder`**: Instance profile for Image Builder instances

**Policy Attachments**:
- **SSM Core Policy**: Enables Systems Manager agent functionality
- **Image Builder Permissions**: Custom policy for AMI creation and management
- **Lifecycle Execution Policy**: AWS-managed policy for Image Builder operations

**Configuration Notes**:
- Separate roles for different service functions (runtime vs. build)
- Instance profiles enable EC2 instances to assume IAM roles
- Follows AWS security best practices with service-specific permissions

**Dependencies**: Uses trust policies from `data.tf`

**Relationships**: Instance profiles referenced by launch templates and Image Builder configuration

---

### Image Building Pipeline

#### **`imagebuilder.tf`** - EC2 Image Builder Configuration
**Purpose**: Automates custom AMI creation with scheduled builds and testing

**Key Resources**:
- **`aws_imagebuilder_component.custom_scripts`**: Custom component for project-specific tooling
- **`aws_imagebuilder_component.os_tooling`**: OS-level hardening and tool installation
- **`aws_imagebuilder_image_recipe.custom_recipe`**: Combines base AMI with custom components
- **`aws_imagebuilder_infrastructure_configuration.infra`**: Build environment specification
- **`aws_imagebuilder_distribution_configuration.dist`**: AMI distribution and tagging
- **`aws_imagebuilder_image_pipeline.pipeline`**: Orchestrates the complete build process

**Pipeline Configuration**:
- **Schedule**: Weekly builds (Tuesdays at 02:00 UTC)
- **Base Image**: Latest Amazon Linux 2023 ARM64 from AWS Parameter Store
- **Build Environment**: Private subnet with Graviton instance types
- **Testing**: 60-minute timeout with automated validation
- **Distribution**: Automatic AMI tagging and Parameter Store updates

**Configuration Notes**:
- Component execution order: OS tooling first, then custom scripts
- Enhanced metadata collection for detailed build tracking
- Automatic cleanup of build instances on completion or failure
- Lifecycle management prevents Terraform from recreating recipes unnecessarily

**Dependencies**: Requires VPC subnets, security groups, IAM roles, and SSM parameters

**Relationships**: Outputs AMI IDs to Parameter Store, triggers EventBridge events

---

### Automation and Event Processing

#### **`lambda.tf`** - Lambda Function for Launch Template Updates
**Purpose**: Serverless automation for updating launch templates with new AMI IDs

**Key Resources**:
- **`aws_iam_role.lambda-ltupdater`**: Lambda execution role with required permissions for the launch template updater function. 
- **`aws_iam_policy.ltupdater-lambda_policy`**: Custom policy for EC2 and SSM access
- **`aws_lambda_function.update_launch_template`**: Python function for launch template updates
- **`aws_lambda_permission.allow_eventbridge`**: Allows EventBridge to invoke the function
- **`aws_lambda_function.ami_retention`**: Python function for housekeeping AMI Images produced by Image Builder
- **`aws_lambda_permission.allow_eventbridge_amicleaner`**: Allows EventBridge to invoke the function

**Function Configuration - ltupdater**:
- **Runtime**: Python 3.12 for optimal performance and security
- **Timeout**: 60 seconds for reliable completion
- **VPC Integration**: Runs in private subnets with security group restrictions
- **Environment Variables**: Configurable parameters for launch template and instance settings

**Automation Logic - ltupdater**:
1. Retrieves latest AMI ID from Systems Manager Parameter Store
2. Creates new launch template version with updated AMI
3. Sets new version as default for Auto Scaling Group
4. Provides detailed logging for troubleshooting

**Function Configuration - amicleaner**:
- **Runtime**: Python 3.12 for optimal performance and security
- **Timeout**: 300 seconds for reliable completion
- **VPC Integration**: Runs in private subnets with security group restrictions
- **Environment Variables**: Configurable parameters for launch template, "dry-run" mode, and number of AMIs (and Snapshots) to keep 

**Automation Logic - amicleaner**:
1. Retrieves latest AMI ID from Systems Manager Parameter Store
2. Creates new launch template version with updated AMI
3. Sets new version as default for Auto Scaling Group
4. Provides detailed logging for troubleshooting

**Configuration Notes**:
- VPC deployment enables secure access to private AWS APIs and access to VPC flow logs related to the lambda functions - meaning GuardDuty has better insight. 
- Environment variables allow flexible configuration without code changes
- IAM policies follow least-privilege principles with specific resource access

**Dependencies**: Requires IAM policies from `data.tf`, VPC configuration, and security groups

**Relationships**: Triggered by EventBridge, updates launch templates, reads from Parameter Store

---

#### **`eventbridge.tf`** - Event-Driven Workflow Orchestration
**Purpose**: Connects Image Builder pipeline completion events to Lambda automation

**Key Resources**:
- **`aws_cloudwatch_event_rule.imagebuilder_completed`**: Captures Image Builder state change events
- **`aws_cloudwatch_event_target.trigger_lambda`**: Routes matching events to Lambda function

**Event Pattern**:
```json
{
  "source": ["aws.imagebuilder"],
  "detail-type": ["EC2 Image Builder Image State Change"],
  "detail": {
    "state": {
      "status": ["AVAILABLE"]
    }
  }
}
```

**Configuration Notes**:
- Event filtering ensures only successful builds trigger automation
- Loose coupling between Image Builder and launch template updates
- Automatic retry and error handling through EventBridge service
- Enables audit trail of all automation events

**Dependencies**: Requires Lambda function ARN for event target configuration

**Relationships**: Bridges Image Builder pipeline completion with launch template automation

---

### Compute Infrastructure

#### **`ec2-asg.tf`** - Auto Scaling Group and Launch Template
**Purpose**: Manages scalable compute infrastructure with automated AMI updates

**Key Resources**:
- **`aws_launch_template.custom_lt`**: Versioned instance configuration template
- **`aws_autoscaling_group.custom_asg`**: Auto Scaling Group for dynamic instance management

**Launch Template Configuration**:
- **AMI Reference**: Uses Parameter Store value for automatic updates
- **Instance Type**: Configurable Graviton-based instances (t4g.small default)
- **Security**: VPC security groups and IAM instance profile
- **Storage**: 20GB encrypted GP3 EBS volume
- **Tagging**: Consistent resource tagging for management and billing

**Auto Scaling Group Settings**:
- **Capacity**: 0-1 instances (configurable for production workloads)
- **Multi-AZ**: Deploys across private subnets in multiple availability zones
- **Health Checks**: EC2-based health monitoring with 300-second grace period
- **Launch Template**: Always uses `$Latest` version for automatic AMI updates

**Configuration Notes**:
- Launch template versioning enables zero-downtime AMI updates
- Encrypted storage ensures data protection at rest
- Instance tagging propagation maintains consistent resource identification
- Health check configuration balances responsiveness with stability

**Dependencies**: Requires Parameter Store AMI ID, VPC subnets, security groups, and IAM instance profile

**Relationships**: Uses AMI IDs from Parameter Store, updated by Lambda function automation

---

### Parameter Management

#### **`ssm.tf`** - Systems Manager Parameter Store
**Purpose**: Secure storage and management of AMI identifiers for automated updates

**Key Resources**:
- **`aws_ssm_parameter.custom_built_custom_id`**: Parameter storing latest custom AMI ID

**Parameter Configuration**:
- **Name**: `/imagebuilder/{project}/custom_id` (hierarchical naming)
- **Type**: String with `aws:ec2:image` data type for AMI validation
- **Initial Value**: Base Amazon Linux 2023 AMI ID for first deployment
- **Lifecycle Management**: Terraform ignores value changes (managed by Image Builder)

**Integration Points**:
- **Image Builder**: Automatically updates parameter value on successful builds
- **Launch Template**: References parameter for AMI selection
- **Lambda Function**: Reads parameter for launch template updates

**Configuration Notes**:
- Data type validation ensures only valid AMI IDs are stored
- Lifecycle policy prevents Terraform from overwriting Image Builder updates
- Hierarchical naming supports multiple projects and environments
- Secure parameter access through IAM policies

**Dependencies**: Uses base AMI data source for initial value

**Relationships**: Central integration point for AMI lifecycle management across all services

---

### Component Relationships and Data Flow

#### **Build Pipeline Flow**
1. **EventBridge Schedule** → **Image Builder Pipeline** (weekly trigger)
2. **Image Builder** → **Parameter Store** (AMI ID update)
3. **Image Builder** → **EventBridge Event** (state change notification)
4. **EventBridge Rule** → **Lambda Function** (event-driven trigger)
5. **Lambda Function** → **Launch Template** (version update)

#### **Runtime Infrastructure Flow**
1. **Launch Template** → **Parameter Store** (AMI ID reference)
2. **Auto Scaling Group** → **Launch Template** (instance configuration)
3. **EC2 Instances** → **IAM Instance Profile** (runtime permissions)
4. **All Resources** → **VPC/Security Groups** (network isolation)

#### **Security and Access Flow**
1. **IAM Roles** → **Service Trust Policies** (service authentication)
2. **IAM Policies** → **AWS APIs** (resource access control)
3. **Security Groups** → **Network Traffic** (network-level filtering)
4. **Parameter Store** → **IAM Permissions** (secure configuration access)

This comprehensive file structure creates a fully automated, event-driven infrastructure pattern that eliminates manual AMI management while maintaining security, scalability, and operational excellence.

## Event-Driven Automation Workflow

This section provides deep technical details about the event-driven patterns and automation workflows that make this architecture fully autonomous.

### EventBridge Integration Patterns

#### **Schedule-Based Triggers**
```hcl
schedule {
  schedule_expression                = "cron(0 2 ? * TUE *)"
  pipeline_execution_start_condition = "EXPRESSION_MATCH_ONLY"
}
```

- **Cron Expression**: `0 2 ? * TUE *` (02:00 UTC every Tuesday)
- **Execution Condition**: `EXPRESSION_MATCH_ONLY` ensures builds only occur on schedule
- **Timezone**: UTC for consistent global execution regardless of regional settings
- **Frequency**: Weekly builds balance security currency with resource costs

#### **Complete Automation Flow Sequence**
```mermaid
sequenceDiagram
    participant EB as EventBridge Schedule
    participant IB as Image Builder Pipeline
    participant PS as Parameter Store
    participant EBR as EventBridge Rule
    participant LF as Lambda Function
    participant LT as Launch Template
    participant ASG as Auto Scaling Group
    participant EC2 as EC2 Instances

    Note over EB,EC2: Weekly Automation Cycle (Every Tuesday 02:00 UTC)
    
    EB->>IB: Trigger Pipeline Execution
    Note over IB: Build Process (30-45 minutes)
    IB->>IB: Provision Build Instance
    IB->>IB: Install OS Tooling Component
    IB->>IB: Install Custom Scripts Component
    IB->>IB: Run Automated Tests (60min timeout)
    IB->>IB: Create AMI with timestamp name
    IB->>PS: Update Parameter with new AMI ID
    IB->>EBR: Emit "AVAILABLE" State Change Event
    
    Note over EBR,LF: Event-Driven Launch Template Update
    EBR->>LF: Trigger Lambda Function
    LF->>PS: Retrieve Latest AMI ID
    LF->>LT: Create New Launch Template Version
    LF->>LT: Set New Version as Default
    
    Note over ASG,EC2: Automatic Instance Updates
    ASG->>LT: Reference $Latest Version
    ASG->>EC2: New Instances Use Updated AMI
    
    Note over EB,EC2: Next cycle in 7 days
```

#### **State Change Event Processing**
```hcl
resource "aws_cloudwatch_event_rule" "imagebuilder_completed" {
  name          = "${var.project}-imagebuilder-completed"
  description   = "Trigger on successful Image Builder builds"
  event_pattern = jsonencode({
    source      = ["aws.imagebuilder"]
    detail-type = ["EC2 Image Builder Image State Change"]
    detail = {
      state = {
        status = ["AVAILABLE"]
      }
    }
  })
}
```

The EventBridge rule captures specific Image Builder events with this structure:

```json
{
  "source": ["aws.imagebuilder"],
  "detail-type": ["EC2 Image Builder Image State Change"],
  "detail": {
    "state": {
      "status": ["AVAILABLE"]
    },
    "name": "project-name-pipeline",
    "outputResources": {
      "amis": [
        {
          "region": "eu-west-1",
          "image": "ami-xxxxxxxxx",
          "name": "project-name-2024-01-15T02-30-45-000Z"
        }
      ]
    }
  }
}
```

**Event Processing Logic**:
- **Source Filter**: `aws.imagebuilder` identifies the service origin
- **Detail Type**: Specific to Image Builder state changes
- **Status Filter**: Only "AVAILABLE" status triggers downstream actions (filters out BUILDING, TESTING, FAILED states)
- **Output Resources**: Contains new AMI details including ID, name, and region
- **Event Target**: Routes matching events directly to Lambda function for processing

### Lambda Automation Function

#### **Function Architecture**
```python
def handler(event, context):
    # Get latest AMI from SSM Parameter Store
    response = ssm.get_parameter(Name=PARAM_NAME)
    ami_id = response["Parameter"]["Value"]

    # Create new launch template version with updated AMI
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

    # Get the latest version number and set as default
    latest = ec2.describe_launch_template_versions(
        LaunchTemplateId=LT_ID,
        Versions=["$Latest"]
    )["LaunchTemplateVersions"][0]["VersionNumber"]

    ec2.modify_launch_template(
        LaunchTemplateId=LT_ID,
        DefaultVersion=str(latest)
    )

    return {"statusCode": 200, "ami_id": ami_id}
```

#### **Automation Execution Steps**
1. **Parameter Retrieval**: Function reads latest AMI ID from `/imagebuilder/{project}/custom_id`
2. **Version Creation**: Creates new launch template version with updated AMI while preserving all other configuration
3. **Version Management**: Retrieves the newly created version number using `$Latest` reference
4. **Default Update**: Sets the new version as default for immediate use by Auto Scaling Group
5. **Response Logging**: Returns success status with AMI ID for audit trail

#### **Environment Configuration**
The Lambda function uses environment variables for flexible configuration:

- **`SSM_PARAM_NAME`**: `/imagebuilder/{project}/custom_id` - Parameter Store location
- **`LAUNCH_TEMPLATE_ID`**: Target launch template for updates
- **`INSTANCE_TYPE`**: EC2 instance type for new versions
- **`SECURITY_GROUP_ID`**: Security group for instance network access
- **`IAM_INSTANCE_PROFILE`**: IAM profile for EC2 instance permissions

#### **VPC Integration**
```hcl
vpc_config {
  subnet_ids         = module.vpc.private_subnets
  security_group_ids = [aws_security_group.lambda.id]
}
```

- **Private Subnet Deployment**: Lambda runs in private subnets for security
- **Security Group**: Allows HTTPS outbound for AWS API calls only
- **NAT Gateway Access**: Enables secure internet access for AWS service communication

### Systems Manager Parameter Store Integration

#### **Parameter Configuration**
```hcl
resource "aws_ssm_parameter" "custom_built_custom_id" {
  name        = "/imagebuilder/${var.project}/custom_id"
  description = "SSM Parameter for storing the AMI ID of the image built from Image Builder"
  type        = "String"
  data_type   = "aws:ec2:image"
  value       = data.aws_ami.al2023.id
  
  lifecycle {
    ignore_changes = [value]
  }
}
```

**Key Features**:
- **Data Type**: `aws:ec2:image` provides AMI-specific validation
- **Lifecycle Management**: Terraform ignores value changes (managed by Image Builder)
- **Initial Value**: Set to base Amazon Linux 2023 AMI for first deployment
- **Automatic Updates**: Image Builder distribution configuration updates the value

#### **Cross-Service Communication**
1. **Image Builder → Parameter Store**: Distribution configuration automatically updates parameter
2. **Parameter Store → Lambda**: Function retrieves latest AMI ID for launch template updates
3. **Parameter Store → Launch Template**: Template references parameter for AMI selection

### Launch Template Versioning Strategy

#### **Version Management**
```hcl
launch_template {
  id      = aws_launch_template.custom_lt.id
  version = "$Latest"
}
```

- **Automatic Versioning**: Lambda creates new versions for each AMI update
- **Default Version**: New versions automatically become the default
- **ASG Integration**: Auto Scaling Group always uses `$Latest` version
- **Rollback Capability**: Previous versions remain available for emergency rollback

#### **Configuration Consistency**
Each new launch template version maintains:
- **Instance Type**: Consistent across all versions
- **Security Groups**: Same network access patterns
- **IAM Instance Profile**: Unchanged permissions model
- **EBS Configuration**: Consistent storage settings (encrypted, GP3, 20GB)
- **Tags**: Standardized tagging for resource management

### Image Builder Pipeline Automation

#### **Component Management**
```hcl
component { component_arn = aws_imagebuilder_component.os_tooling.arn }
component { component_arn = aws_imagebuilder_component.custom_scripts.arn }
```

**Component Execution Order**:
1. **OS Tooling Component**: System-level hardening and tool installation
2. **Custom Scripts Component**: Application-specific configuration and tooling

#### **Build Infrastructure**
```hcl
resource "aws_imagebuilder_infrastructure_configuration" "infra" {
  instance_types                = var.build_instance_types
  subnet_id                     = module.vpc.private_subnets[0]
  security_group_ids            = [aws_security_group.MyExampleSG.id]
  terminate_instance_on_failure = true
}
```

**Security Features**:
- **Private Subnet**: Build instances run in isolated network environment
- **Automatic Cleanup**: Failed builds automatically terminate instances
- **Security Groups**: Minimal network access for build process
- **Instance Profile**: Least-privilege permissions for build operations

#### **Testing and Validation**
```hcl
image_tests_configuration {
  image_tests_enabled = true
  timeout_minutes     = 60
}
```

- **Automated Testing**: Built-in tests validate AMI functionality before distribution
- **Timeout Protection**: 60-minute limit prevents runaway build processes
- **Quality Gates**: Only tested, validated AMIs trigger downstream automation

### Error Handling and Resilience

#### **Lambda Function Resilience**
- **Timeout Configuration**: 60-second limit ensures timely completion
- **Error Logging**: CloudWatch logs capture detailed error information
- **Retry Logic**: EventBridge provides automatic retry for failed invocations
- **Dead Letter Queue**: Can be configured for failed event processing

#### **Pipeline Failure Handling**
- **Build Failures**: Failed Image Builder runs don't trigger Lambda updates
- **Event Filtering**: Only successful builds ("AVAILABLE" status) proceed
- **Infrastructure Isolation**: Build failures don't affect running instances
- **Rollback Capability**: Previous AMI versions remain available

#### **Monitoring and Observability**
- **CloudWatch Integration**: All services provide metrics and logs in CloudWatch
- **EventBridge Metrics**: Track event processing success rates
- **Lambda Metrics**: Monitor function execution and error rates
- **Image Builder Logs**: Detailed build process logging for troubleshooting

This event-driven architecture provides a robust, scalable foundation for automated infrastructure management while maintaining security, reliability, and operational excellence.

## Customization Options

This section provides comprehensive guidance on customizing the autoscaling with Image Builder infrastructure to meet your specific requirements. The architecture is designed to be flexible and extensible while maintaining security and operational best practices.

### Variable Configuration

#### **Core Project Variables**
The `terraform.tfvars` file provides the primary customization interface:

```hcl
# terraform.tfvars - Basic Configuration
region       = "eu-west-1"           # Change to your preferred AWS region
project      = "MyCustomProject"     # Unique project identifier (alphanumeric + hyphens)
instance_type = "t4g.medium"         # Adjust based on workload requirements

# Advanced Configuration
build_instance_types = ["t4g.medium", "t4g.large"]  # Image Builder instance types
default_tags = {
  Owner       = "TeamName"
  Project     = "MyCustomProject"
  Environment = "Production"         # Development, Staging, Production
  CostCenter  = "Engineering"
}
```


**Build Instance Types:**
- Use multiple instance types for Image Builder flexibility
- Larger instances reduce build time but increase costs
- Consider `c6g` family for CPU-intensive build processes


### Monitoring and Debugging

#### **CloudWatch Logs**

**Useful Log Groups to Monitor:**
- `/aws/imagebuilder/instance` - Image Builder build logs
- `/aws/lambda/ltupdater` - Lambda function execution logs
- `/aws/events/rule/imagebuilder-completed` - EventBridge rule logs

## Additional Resources

### AWS Documentation
- **[EC2 Image Builder User Guide](https://docs.aws.amazon.com/imagebuilder/latest/userguide/)**
- **[Auto Scaling User Guide](https://docs.aws.amazon.com/autoscaling/ec2/userguide/)**
- **[EventBridge User Guide](https://docs.aws.amazon.com/eventbridge/latest/userguide/)**
- **[Lambda Developer Guide](https://docs.aws.amazon.com/lambda/latest/dg/)**
- **[Systems Manager Parameter Store](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html)**

### Best Practices Guides
- **[AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)**
- **[AWS Security Best Practices](https://aws.amazon.com/architecture/security-identity-compliance/)**
- **[Cost Optimization Pillar](https://docs.aws.amazon.com/wellarchitected/latest/cost-optimization-pillar/welcome.html)**
- **[Operational Excellence Pillar](https://docs.aws.amazon.com/wellarchitected/latest/operational-excellence-pillar/welcome.html)**

### Terraform Resources
- **[Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)**
- **[Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)**
- **[AWS VPC Module](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest)**

### Tools and Utilities
- **[AWS CLI Reference](https://docs.aws.amazon.com/cli/latest/reference/)**
- **[Terraform CLI Documentation](https://www.terraform.io/docs/cli/index.html)**
- **[AWS CloudFormation Template Reference](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/template-reference.html)**

---

## Summary

This comprehensive README provides everything needed to understand, deploy, customize, and operate the autoscaling with Image Builder infrastructure pattern. The architecture demonstrates modern AWS best practices for automated infrastructure management while maintaining security, cost efficiency, and operational excellence.

### Key Takeaways

- **Event-Driven Architecture**: Fully automated AMI lifecycle management through AWS native services
- **Zero-Touch Operations**: No manual intervention required for AMI updates and deployments
- **Extensible Design**: Modular architecture supports advanced patterns and enterprise requirements
- **Cost Optimized**: Graviton instances, efficient scheduling, and resource right-sizing

### Getting Started Checklist

- [ ] Review [Prerequisites](#prerequisites) and ensure all requirements are met
- [ ] Configure [terraform.tfvars](#step-2-configure-variables) with your specific settings
- [ ] Follow [Deployment Instructions](#deployment-instructions) step by step
- [ ] Verify deployment using the [validation commands](#step-6-verify-deployment)
- [ ] Monitor first Image Builder execution and Lambda automation
- [ ] Customize the infrastructure using [Customization Options](#customization-options)
- [ ] Implement [Best Practices](#best-practices) for production deployment

### Next Steps After Deployment

Once you have successfully deployed this infrastructure, consider these next steps:

1. **Monitor Your First Build**: Watch the Image Builder pipeline execute its first scheduled build
2. **Test Scaling**: Manually adjust Auto Scaling Group capacity to observe the automation
3. **Customize Components**: Modify the Image Builder components for your specific requirements
4. **Implement Monitoring**: Set up CloudWatch dashboards and alerts for production use
5. **Cost Optimization**: Monitor AWS costs and explore methods for reducing where possible

### Contributing

This project serves as an educational resource. If you find improvements or have suggestions:
- Review the architecture patterns and suggest enhancements
- Share your customizations and use cases
- Report issues or unclear documentation
- Contribute additional examples or extensions

### Further Reading 

- **Troubleshooting**: Check the [Troubleshooting](#troubleshooting) section for common issues
- **Learning**: Explore [Additional Resources](#additional-resources) for deeper AWS knowledge
- **Architecture**: Review [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/) principles