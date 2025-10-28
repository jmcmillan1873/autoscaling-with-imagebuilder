variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "project" {
  type    = string
  default = "MyExampleProject"
}

variable "instance_type" {
  type    = string
  default = "t4g.small"
}

variable "build_instance_types" {
  type    = list(string)
  default = ["t4g.small", "t4g.medium", "t4g.large", "t4g.2xlarge"]
}

#
# Define common environment variables
#
variable "default_tags" {
  type        = map(string)
  description = "Tags to apply to every resource regardless of type"
  default = {
    Owner       = "MeMyselfAndI"
    Project     = "MyExampleProject"
    Environment = "Example"
  }
}
