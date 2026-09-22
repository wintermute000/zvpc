################################################################################
# AWS Systems Manager (SSM) Session Manager access
#
# Replaces the public bastion host as the administrative entry point. Workloads
# and Cloud Connectors are reached via Session Manager (no inbound ports, no
# public IPs); SSH on port 22 is retained on the instances and reached via ZPA.
#
# Interface endpoints are mandatory in this VPC rather than optional. The VPC
# module is created with create_private_nat_gateway_route = false (main.tf), and
# aws_route.private_default_to_cc (cloudconnectors.tf) points every private
# subnet default route at the Cloud Connector ENIs. Private subnets therefore
# have no NAT path, and Session Manager's long-lived ssmmessages websockets
# would otherwise have to survive the CC -> ZIA path. Endpoint ENIs live inside
# the private subnets, so this traffic is carried by the VPC local route and
# never reaches the Cloud Connector default route.
################################################################################

locals {
  # ssm          - Systems Manager control API
  # ssmmessages  - Session Manager data channel
  # ec2messages  - SSM Agent to service messaging
  ssm_endpoint_services = toset(["ssm", "ssmmessages", "ec2messages"])
}


################################################################################
# Security Group for the SSM interface endpoints
#
# Ingress 443 from the VPC only. No egress rule is declared: Terraform strips
# the AWS default allow-all, and interface endpoints never initiate connections
# (return traffic is handled statefully).
################################################################################
resource "aws_security_group" "ssm_endpoints" {
  name        = "${var.name_prefix}-ssm-endpoints-sg-${random_string.suffix.result}"
  description = "Allow HTTPS from the VPC to the SSM interface endpoints"
  vpc_id      = module.vpc.vpc_id

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.global_tags,
    { Name = "${var.name_prefix}-ssm-endpoints-sg-${random_string.suffix.result}" }
  )
}

resource "aws_security_group_rule" "ssm_endpoints_https" {
  description       = "HTTPS from within the VPC to the SSM interface endpoints"
  protocol          = "TCP"
  from_port         = 443
  to_port           = 443
  type              = "ingress"
  cidr_blocks       = [module.vpc.vpc_cidr_block]
  security_group_id = aws_security_group.ssm_endpoints.id
}


################################################################################
# SSM Interface Endpoints
#
# private_dns_enabled is VPC-wide, so Cloud Connectors in aws_subnet.cc_subnet
# will also resolve the SSM service names to these private IPs and reach them
# over the local route rather than via their NAT gateway path.
################################################################################
resource "aws_vpc_endpoint" "ssm" {
  for_each = local.ssm_endpoint_services

  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.ssm_endpoints.id]
  private_dns_enabled = true

  tags = merge(local.global_tags,
    { Name = "${var.name_prefix}-${each.key}-endpoint-${random_string.suffix.result}" }
  )
}
