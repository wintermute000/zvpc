################################################################################
# Map default tags with values to be assigned to all tagged resources
################################################################################
locals {
  global_tags = {
    Owner                                                                                = var.owner_tag
    ManagedBy                                                                            = "terraform"
    Vendor                                                                               = "Zscaler"
    "zs-app-connector-cluster/${var.name_prefix}-cluster-${random_string.suffix.result}" = "shared"
  }
}

################################################################################
# Generate a unique random string for resource name assignment and key pair
################################################################################
resource "random_string" "suffix" {
  length  = 8
  upper   = false
  special = false
}


################################################################################
# 1. Create VPC
################################################################################

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = ">=6.6.0"

  name = var.vpc_name
  cidr = var.cidr

  azs             = var.azs
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets


  # Enable NAT gateways for outbound internet access from private subnets
  enable_nat_gateway = true
  single_nat_gateway = false # Set to true to create a single NAT gateway
  one_nat_gateway_per_az = true # Set to true to create a NAT gateway per AZ


  # Enable private subnet default route to be changed to cloud connectors
  create_private_nat_gateway_route = false

  # Add tags to all resources created by the module
  tags = local.global_tags

}


################################################################################
# 2. Administrative access
#
# The public bastion host has been retired in favour of AWS SSM Session Manager
# (see ssm.tf) for out-of-band access, and SSH over ZPA for workload shell
# access via the App Connectors in the private subnets.
################################################################################
