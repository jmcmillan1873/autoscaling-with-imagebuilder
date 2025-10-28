#
# Locals that should be dynamic 
#

locals {
  # grab the local account id 
  account_id = data.aws_caller_identity.current.account_id
}
