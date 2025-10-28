
module "vpc" {
  # Use the commit hash to source version 6.0.1 of the VPC module. Update this comment when you update the hash to pull a more recent version
  source               = "git::https://github.com/terraform-aws-modules/terraform-aws-vpc.git?ref=a0307d4d1807de60b3868b96ef1b369808289157"
  name                 = "${var.project}-vpc"
  cidr                 = "11.0.0.0/16"
  azs                  = ["${var.region}a", "${var.region}b"]
  public_subnets       = ["11.0.1.0/24", "11.0.2.0/24"]
  private_subnets      = ["11.0.101.0/24", "11.0.102.0/24"]
  create_igw           = true
  enable_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true
  single_nat_gateway   = true

  tags = merge(
    var.default_tags
  )

}
