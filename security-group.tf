################################################################################
# Security Groups - Network Access Control
################################################################################
# This file defines security groups that implement network-level access control
# for infrastructure components. Security groups act as virtual firewalls,
# controlling inbound and outbound traffic at the instance level.
#
# Security Architecture:
# - MyExampleSG: Main security group for EC2 instances and Image Builder
# - lambda: Dedicated security group for Lambda functions
#
# Security Principles Applied:
# - Least privilege: Only necessary ports are allowed
# - Defense in depth: Multiple layers of security
# - Egress-only where possible: Minimize inbound access
# - HTTPS only: Encrypted communication
# - No SSH access: Enforce immutable infrastructure pattern
################################################################################

################################################################################
# Main Security Group (EC2 Instances and Image Builder)
################################################################################
# This security group is attached to:
# - Auto Scaling Group EC2 instances (via launch template)
# - Image Builder temporary build instances (via infrastructure config)
#
# Purpose: Allow HTTPS communication for AWS API calls and package downloads
################################################################################

resource "aws_security_group" "MyExampleSG" {
  # Security group name includes project identifier
  # Visible in AWS Console, flow logs, and CloudTrail events
  name = "${var.project}-sg"
  
  # Description appears in AWS Console and helps operators understand usage
  # Note: Original description mentions "scanbox" (historical artifact)
  # In practice, this SG is used for all EC2 instances and Image Builder
  description = "Egress-only SG for scanbox"
  
  # VPC Association
  # Security groups are VPC-specific and cannot span VPCs
  # Must be in the same VPC as the resources that use it
  vpc_id = module.vpc.vpc_id

  # Egress Rule: Outbound HTTPS Traffic
  # Allows instances to initiate outbound HTTPS connections
  # Required for:
  # - AWS API calls (EC2, SSM, Image Builder, CloudWatch)
  # - Package downloads (yum/dnf repositories, pip, npm, etc.)
  # - Software updates (OS patches, security updates)
  # - Third-party APIs (if application needs them)
  egress {
    description = "allow HTTPS"
    
    # Port 443: HTTPS (encrypted HTTP)
    from_port = 443
    to_port   = 443
    
    # Protocol: TCP (HTTPS uses TCP)
    protocol = "tcp"
    
    # Destination: 0.0.0.0/0 (anywhere on the internet)
    # Allows connection to any HTTPS endpoint
    # In high-security environments, consider restricting to specific IPs:
    # - AWS service endpoints (use prefix lists)
    # - Approved package repositories
    # - Known third-party APIs
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Ingress Rule: Inbound HTTPS Traffic
  # Allows instances to receive HTTPS connections from anywhere
  # 
  # IMPORTANT SECURITY CONSIDERATION:
  # This ingress rule may not be necessary for this architecture since:
  # - Instances run in private subnets (no direct internet access)
  # - No load balancer is configured
  # - Application doesn't expose HTTPS endpoints
  #
  # Potential use cases:
  # - Future: Add Application Load Balancer
  # - Future: Internal service-to-service communication
  # - Testing: Temporary access for troubleshooting
  #
  # Recommendation for production:
  # - Remove this rule if not needed (reduce attack surface)
  # - If needed, restrict source to specific security groups or CIDRs
  # - Add AWS WAF if exposing public endpoints
  ingress {
    description = "allow HTTPS"
    
    # Port 443: HTTPS
    from_port = 443
    to_port   = 443
    
    # Protocol: TCP
    protocol = "tcp"
    
    # Source: 0.0.0.0/0 (anywhere)
    # Consider restricting based on actual requirements:
    # - Load balancer security group
    # - VPC CIDR (internal only)
    # - Specific IP ranges
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # Resource Tags
  tags = {
    Name = "${var.project}-sg"
  }
}

# Security Group Notes:
# - No SSH (port 22) access: Follows immutable infrastructure principles
# - No RDP (port 3389) for Windows: Not applicable (Linux AMI)
# - No HTTP (port 80): Forces HTTPS for security
# - Stateful: Return traffic is automatically allowed
# - Changes take effect immediately (no instance restart needed)


################################################################################
# Lambda Security Group
################################################################################
# This security group is attached to Lambda functions running in VPC:
# - ltupdater: Launch Template updater function
# - amicleaner: AMI cleanup function
#
# Purpose: Allow outbound HTTPS for AWS API calls only (no inbound access needed)
################################################################################

resource "aws_security_group" "lambda" {
  # Security group name specific to Lambda functions
  name = "lambda-sg"
  
  # Description clearly indicates Lambda-specific usage
  description = "SG for Lambda functions"
  
  # VPC Association
  # Lambda functions must use the same VPC as other resources they interact with
  vpc_id = module.vpc.vpc_id

  # Egress Rule: Outbound HTTPS Only
  # Lambda functions need HTTPS to call AWS APIs:
  # - EC2: DescribeLaunchTemplates, CreateLaunchTemplateVersion, ModifyLaunchTemplate
  # - EC2: DescribeImages, DeregisterImage, DeleteSnapshot
  # - SSM: GetParameter
  # - CloudWatch Logs: PutLogEvents (via VPC endpoint or NAT)
  egress {
    description = "allow HTTPS"
    
    # Port 443: HTTPS for AWS API calls
    from_port = 443
    to_port   = 443
    
    # Protocol: TCP
    protocol = "tcp"
    
    # Destination: 0.0.0.0/0 (AWS service endpoints)
    # Lambda needs access to AWS service endpoints in the region
    # These endpoints are on the public internet (even when using VPC)
    # 
    # Alternative: VPC Endpoints
    # For enhanced security and reduced data transfer costs, consider adding:
    # - com.amazonaws.{region}.ec2: EC2 API calls
    # - com.amazonaws.{region}.ssm: Systems Manager calls
    # - com.amazonaws.{region}.logs: CloudWatch Logs
    # VPC endpoints allow Lambda to reach AWS services without NAT Gateway
    cidr_blocks = ["0.0.0.0/0"]
  }

  # No Ingress Rules
  # Lambda functions don't need inbound network access because:
  # - Triggered by EventBridge (internal AWS service communication)
  # - Don't expose HTTP/HTTPS endpoints (use Function URLs or API Gateway for that)
  # - Don't accept direct network connections
  # 
  # This follows the principle of least privilege:
  # Only allow outbound connections that the function initiates

  # Resource Tags
  tags = {
    Name = "lambda-sg"
  }
}

# Lambda Security Group Benefits:
# - Separate from EC2 instances (blast radius reduction)
# - No inbound access (reduced attack surface)
# - Can be monitored separately (VPC Flow Logs, GuardDuty)
# - IAM policies still control what Lambda can do (defense in depth)


################################################################################
# Security Best Practices Implemented
################################################################################
#
# 1. SEPARATE SECURITY GROUPS
#    - Different security groups for different service types
#    - Easier to audit and manage
#    - Reduces blast radius of misconfiguration
#
# 2. EGRESS-ONLY LAMBDA
#    - Lambda SG has no ingress rules
#    - Follows principle of least privilege
#    - Lambda functions can't be directly accessed
#
# 3. HTTPS ONLY
#    - All traffic encrypted in transit
#    - No plaintext HTTP allowed
#    - Protects sensitive data and credentials
#
# 4. NO SSH/RDP
#    - Enforces immutable infrastructure
#    - Reduces attack surface
#    - Encourages automation and logging
#
# 5. STATEFUL FILTERING
#    - AWS security groups are stateful
#    - Return traffic automatically allowed
#    - Simplifies rule management
#
# 6. VPC FLOW LOGS (Recommended Addition)
#    - Enable VPC Flow Logs to monitor all traffic
#    - Helps with troubleshooting and security auditing
#    - Can feed into CloudWatch Logs Insights or S3
#
# 7. GUARD DUTY INTEGRATION
#    - GuardDuty can detect anomalous network behavior
#    - Monitors for crypto mining, data exfiltration, etc.
#    - VPC-deployed Lambda functions are better monitored
#
################################################################################

# Future Enhancements to Consider:
# - Add VPC Endpoints to reduce NAT Gateway costs and improve security
# - Enable VPC Flow Logs for network monitoring
# - Implement AWS Network Firewall for advanced threat protection
# - Use Security Group rule descriptions for better documentation
# - Consider using Security Group rule resources for better organization
# - Add CloudWatch metrics for rejected connection attempts
