################################################################################
# Virtual Private Cloud (VPC) Configuration
################################################################################
# This file creates the isolated network environment for all infrastructure
# components. The VPC provides network isolation, controlled internet access
# via NAT Gateway, and spans multiple Availability Zones for high availability.
#
# Network Architecture:
# - CIDR: 11.0.0.0/16 (65,536 IP addresses)
# - 2 Availability Zones for redundancy
# - Public subnets (11.0.1.0/24, 11.0.2.0/24) for NAT Gateway
# - Private subnets (11.0.101.0/24, 11.0.102.0/24) for compute resources
# - Single NAT Gateway for cost optimization
# - Internet Gateway for public subnet connectivity
#
# All compute resources (Image Builder, Lambda, EC2) run in private subnets
# for enhanced security. Outbound internet access is routed through NAT Gateway.
################################################################################

# VPC Module
# Uses the community-maintained terraform-aws-modules/vpc module
# This module is widely adopted and implements AWS best practices
module "vpc" {
  # Source: Official Terraform AWS VPC Module
  # Using Git commit hash for version pinning ensures reproducible builds
  # Hash a0307d4 corresponds to version 6.0.1 of the module
  # To upgrade: Update the commit hash and test thoroughly
  # Module repository: https://github.com/terraform-aws-modules/terraform-aws-vpc
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-vpc.git?ref=a0307d4d1807de60b3868b96ef1b369808289157"
  
  # VPC Name
  # Includes project identifier for easy identification in AWS Console
  # Appears in VPC dashboard, flow logs, and resource lists
  name = "${var.project}-vpc"
  
  # CIDR Block: 11.0.0.0/16
  # Provides 65,536 IP addresses (256 Class C networks)
  # Private IP range (not routable on public internet)
  # 
  # CIDR breakdown:
  # - 11.0.0.0/16 = 11.0.0.0 to 11.0.255.255
  # - Subnet mask: 255.255.0.0
  # - Network bits: 16, Host bits: 16
  #
  # Note: Using 11.0.0.0/16 instead of standard 10.0.0.0/16 or 172.16.0.0/12
  # reduces collision risk with corporate networks during VPN connections
  # For production, consider using terraform variables for CIDR customization
  cidr = "11.0.0.0/16"
  
  # Availability Zones
  # Deploy subnets across two AZs in the selected region
  # Format: ${region}a and ${region}b (e.g., eu-west-1a, eu-west-1b)
  #
  # Multi-AZ deployment provides:
  # - High availability: Survive AZ-level failures
  # - Fault tolerance: Distribute resources across physical locations
  # - Better latency: Place resources closer to users
  # - AWS requirements: Some services require multi-AZ (RDS, Load Balancers)
  #
  # Trade-off: Two AZs balance cost (NAT Gateway per AZ can be expensive)
  # with reliability (more AZs = higher availability but higher cost)
  azs = ["${var.region}a", "${var.region}b"]
  
  # Public Subnets
  # These subnets have routes to the Internet Gateway for direct internet access
  # CIDR: 11.0.1.0/24 (AZ-a) and 11.0.2.0/24 (AZ-b)
  # Each subnet provides 256 IP addresses (251 usable - 5 reserved by AWS)
  #
  # Public subnet resources:
  # - NAT Gateway (requires public IP for outbound internet)
  # - Future: Load Balancers, Bastion hosts (if needed)
  #
  # Reserved IPs per subnet (AWS reserves first 4 and last 1):
  # - 11.0.1.0: Network address
  # - 11.0.1.1: VPC router
  # - 11.0.1.2: DNS server
  # - 11.0.1.3: Future use (reserved by AWS)
  # - 11.0.1.255: Broadcast address (not used in VPC but reserved)
  public_subnets = ["11.0.1.0/24", "11.0.2.0/24"]
  
  # Private Subnets
  # These subnets route internet traffic through NAT Gateway (no direct internet access)
  # CIDR: 11.0.101.0/24 (AZ-a) and 11.0.102.0/24 (AZ-b)
  # Each subnet provides 256 IP addresses (251 usable)
  #
  # Private subnet resources (enhanced security):
  # - Image Builder temporary build instances
  # - Lambda functions (with VPC integration)
  # - Auto Scaling Group EC2 instances
  # - Future: Databases, caches, internal services
  #
  # Security benefits of private subnets:
  # - No direct inbound internet access (reduces attack surface)
  # - Controlled outbound access via NAT Gateway
  # - VPC Flow Logs capture all network traffic
  # - GuardDuty can detect anomalous behavior
  private_subnets = ["11.0.101.0/24", "11.0.102.0/24"]
  
  # Internet Gateway
  # Creates an Internet Gateway for public subnet internet access
  # Required for NAT Gateway functionality (NAT needs public IP)
  # Enables outbound internet access for private subnet resources
  create_igw = true
  
  # NAT Gateway Configuration
  # Creates NAT Gateway(s) for private subnet outbound internet access
  # NAT Gateway provides:
  # - Secure outbound internet for private instances
  # - Static public IP (Elastic IP automatically assigned)
  # - High bandwidth (up to 45 Gbps)
  # - AWS-managed availability
  enable_nat_gateway = true
  
  # Single NAT Gateway
  # Creates one NAT Gateway in first public subnet only
  # 
  # Cost optimization trade-off:
  # - Single NAT: ~$33/month + data transfer (~$0.045/GB)
  # - Multi-AZ NAT: ~$66/month + data transfer (one per AZ)
  #
  # Availability considerations:
  # - Single NAT: AZ failure breaks outbound internet for all private subnets
  # - Multi-AZ NAT: Each AZ independent, survive AZ-level failures
  #
  # Recommendation:
  # - Development/Testing: Single NAT Gateway (cost savings)
  # - Production: Consider multi-AZ NAT (set to false for per-AZ NAT)
  # - Critical workloads: Definitely use per-AZ NAT Gateway
  single_nat_gateway = true
  
  # DNS Hostnames
  # Enable DNS hostnames for instances launched in the VPC
  # When enabled, instances receive public DNS hostnames if they have public IPs
  # Format: ec2-xx-xx-xx-xx.{region}.compute.amazonaws.com
  #
  # Benefits:
  # - Human-readable DNS names for instances
  # - Required for some AWS services (ECS, RDS)
  # - Simplifies troubleshooting and logs
  enable_dns_hostnames = true
  
  # DNS Support
  # Enable DNS resolution within the VPC via Amazon-provided DNS server
  # DNS server is available at VPC CIDR base + 2 (e.g., 11.0.0.2)
  #
  # Benefits:
  # - Resolve AWS service endpoints (s3.amazonaws.com, ec2.amazonaws.com)
  # - Internal hostname resolution
  # - Required for VPC Endpoints
  # - Required for Route53 private hosted zones
  enable_dns_support = true
  
  # Resource Tags
  # Merge project default tags with any additional tags
  # Default tags come from var.default_tags (defined in variables.tf)
  # Applied to all VPC resources: VPC, subnets, route tables, IGW, NAT Gateway
  #
  # VPC module automatically adds:
  # - Name tags for easy identification
  # - Terraform=true tag to indicate IaC management
  tags = merge(
    var.default_tags
  )
  
  # Additional VPC features available but not configured:
  # - enable_vpn_gateway: For VPN connections to on-premises
  # - enable_dhcp_options: Custom DHCP options
  # - enable_flow_logs: VPC Flow Logs for network monitoring
  # - enable_ipv6: IPv6 CIDR block
  # - vpc_endpoints: S3, DynamoDB, etc. VPC endpoints
  # See module documentation for full configuration options
}

# VPC Module Outputs (available for use in other resources):
# - module.vpc.vpc_id: VPC identifier
# - module.vpc.private_subnets: List of private subnet IDs
# - module.vpc.public_subnets: List of public subnet IDs
# - module.vpc.nat_public_ips: NAT Gateway public IP addresses
# - module.vpc.azs: Availability Zone names
# - module.vpc.default_security_group_id: Default security group ID
