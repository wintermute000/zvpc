################################################################################
# Pull VPC information
################################################################################
data "aws_vpc" "selected" {
  id = module.vpc.vpc_id
}


################################################################################
# Pull Amazon Linux 2023 AMI for instance use
################################################################################
data "aws_ssm_parameter" "amazon_linux_latest" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64"
}


################################################################################
# Create pre-defined AWS Security Groups and rules for Workloads
################################################################################
resource "aws_security_group" "workload" {
  name        = "${var.name_prefix}-workload-sg-${random_string.suffix.result}"
  description = "Allow SSH access to workload host and outbound internet access"
  vpc_id      = data.aws_vpc.selected.id

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.global_tags,
    { Name = "${var.name_prefix}-workload-sg-${random_string.suffix.result}" }
  )
}

resource "aws_security_group_rule" "ftp" {
  protocol          = "TCP"
  from_port         = 21
  to_port           = 21
  type              = "ingress"
  cidr_blocks       = var.workload_nsg_source_prefix
  security_group_id = aws_security_group.workload.id
}

resource "aws_security_group_rule" "ssh" {
  protocol          = "TCP"
  from_port         = 22
  to_port           = 22
  type              = "ingress"
  cidr_blocks       = var.workload_nsg_source_prefix
  security_group_id = aws_security_group.workload.id
}

resource "aws_security_group_rule" "HTTP" {
  protocol          = "TCP"
  from_port         = 80
  to_port           = 80
  type              = "ingress"
  cidr_blocks       = var.workload_nsg_source_prefix
  security_group_id = aws_security_group.workload.id
}

resource "aws_security_group_rule" "HTTPS" {
  protocol          = "TCP"
  from_port         = 443
  to_port           = 443
  type              = "ingress"
  cidr_blocks       = var.workload_nsg_source_prefix
  security_group_id = aws_security_group.workload.id
}

resource "aws_security_group_rule" "internet" {
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.workload.id
}

resource "aws_security_group_rule" "intranet" {
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  type              = "egress"
  cidr_blocks       = [data.aws_vpc.selected.cidr_block]
  security_group_id = aws_security_group.workload.id
}


################################################################################
# Define AssumeRole access for EC2
################################################################################
data "aws_iam_policy_document" "workloads_instance_assume_role_policy" {
  version = "2012-10-17"
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}


################################################################################
# Create workloads IAM Role and Host/Instance Profile
################################################################################
resource "aws_iam_role" "workloads_iam_role" {
  name               = "${var.name_prefix}-workloads-iam-role-${random_string.suffix.result}"
  assume_role_policy = data.aws_iam_policy_document.workloads_instance_assume_role_policy.json

  tags = local.global_tags
}


################################################################################
# Define AWS Managed SSM Manager Policy
################################################################################
resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  #policy_arn = "arn:aws:iam::aws:policy/${random_string.suffix.result}"
  policy_arn = "arn:aws:iam::aws:policy/${var.iam_role_policy_ssmcore}"
  role       = aws_iam_role.workloads_iam_role.name
}


################################################################################
# Assign IAM Role to Instance Profile for workloads instance attachment
################################################################################
resource "aws_iam_instance_profile" "workloads_host_profile" {
  name = "${var.name_prefix}-workloads-host-profile-${random_string.suffix.result}"
  role = aws_iam_role.workloads_iam_role.name

  tags = local.global_tags
}


################################################################################
# Create Bastion EC2 host in private subnets
################################################################################
resource "aws_instance" "workloads" {

  # Use for_each to create an instance in each private subnet.
  # We create a map of {az => subnet_id} to iterate over.
  for_each = zipmap(module.vpc.azs, module.vpc.private_subnets)

  ami                         = data.aws_ssm_parameter.amazon_linux_latest.value
  instance_type               = var.workload_instance_type
  key_name                    = var.keypair
  subnet_id                   = each.value
  vpc_security_group_ids      = [aws_security_group.workload.id]
  iam_instance_profile        = aws_iam_instance_profile.workloads_host_profile.name
  associate_public_ip_address = false


  lifecycle {
    ignore_changes = [ami]
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = merge(local.global_tags,
    { Name = "${var.name_prefix}-workload-${each.key}-${random_string.suffix.result}" }
  )
}