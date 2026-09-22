################################################################################
# Create the user_data file with necessary bootstrap variables for Cloud 
# Connector
################################################################################
# 
locals {
  ccuserdata = <<USERDATA
[ZSCALER]
CC_URL=${var.cc_vm_prov_url}
SECRET_NAME=${var.secret_name}
HTTP_PROBE_PORT=${var.http_probe_port}
USERDATA
}

# Write the file to local filesystem for storage/reference
resource "local_file" "ccuser_data_file" {
  content  = local.ccuserdata
  filename = "../ccuser_data"
}


################################################################################
# Locate Latest CC AMI by product code
################################################################################
data "aws_ami" "cloudconnector" {
  most_recent = true

  filter {
    name   = "product-code"
    values = var.aws_region == "cn-north-1" || var.aws_region == "cn-northwest-1" ? ["axnpwhsb4facossmbm1h9yad6"] : ["2l8tfysndbav4tv2nfjwak3cu"]
    #change product code value for China marketplace
  }

  owners = ["aws-marketplace"]
}

################################################################################
# Create dedicated Cloud Connector subnets starting with 21st subnet
################################################################################
resource "aws_subnet" "cc_subnet" {
  count = length(module.vpc.azs)

  vpc_id            = module.vpc.vpc_id
  cidr_block        = cidrsubnet(var.cidr, 8, 21 + count.index)
  availability_zone = module.vpc.azs[count.index]

  tags = {
    Name = "ccsubnet-${module.vpc.azs[count.index]}"
  }
}

# 1. Create one new route table for each Cloud Connector subnet/AZ.
resource "aws_route_table" "cc_subnet_rt" {
  count = length(module.vpc.azs)
  vpc_id = module.vpc.vpc_id

  tags = {
    Name = "rt-ccsubnet-${module.vpc.azs[count.index]}"
  }
}

# 2. Add the default route to each new route table, pointing to the
#    corresponding NAT Gateway from the VPC module.
resource "aws_route" "cc_nat_gateway_route" {
  count = length(module.vpc.azs)

  route_table_id         = aws_route_table.cc_subnet_rt[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  
  # The VPC module outputs a list of NAT Gateway IDs, one per AZ.
  nat_gateway_id         = module.vpc.natgw_ids[count.index]
}

# 3. Associate each Cloud Connector subnet with its new dedicated route table.
#    This replaces your old aws_route_table_association resource.
resource "aws_route_table_association" "cc_subnet_assoc" {
  count = length(aws_subnet.cc_subnet)

  subnet_id      = aws_subnet.cc_subnet[count.index].id
  route_table_id = aws_route_table.cc_subnet_rt[count.index].id
}

################################################################################
# Create Cloud Connectors
################################################################################
module "cc_vm" {
  source                             = "../terraform-aws-cloud-connector-modules/modules/terraform-zscc-ccvm-aws"
  cc_count                           = var.cc_count
  # Fall back to var.ccami_id (Cloud Connector AMI override), not var.ami_id -- the latter is the
  # App Connector override and would build CCs from the wrong appliance image.
  ami_id                             = contains(var.ccami_id, "") ? [data.aws_ami.cloudconnector.id] : var.ccami_id
  name_prefix                        = var.name_prefix
  resource_tag                       = random_string.suffix.result
  global_tags                        = local.global_tags
  mgmt_subnet_id                     = aws_subnet.cc_subnet[*].id
  service_subnet_id                  = aws_subnet.cc_subnet[*].id
  instance_key                       = var.keypair
  user_data                          = local.ccuserdata
  ccvm_instance_type                 = var.ccvm_instance_type
  cc_instance_size                   = var.cc_instance_size
  iam_instance_profile               = module.cc_iam.iam_instance_profile_id
  mgmt_security_group_id             = module.cc_sg.mgmt_security_group_id
  service_security_group_id          = module.cc_sg.service_security_group_id
  ebs_volume_type                    = var.ebs_volume_type
  ebs_encryption_enabled             = var.ebs_encryption_enabled
  byo_kms_key_alias                  = var.byo_kms_key_alias
  hostname_type                      = var.hostname_type
  resource_name_dns_a_record_enabled = var.resource_name_dns_a_record_enabled

  depends_on = [
    null_resource.cc_error_checker
  ]
}

################################################################################
# 5. Create IAM Policy, Roles, and Instance Profiles to be assigned to CC. 
#    Default behavior will create 1 of each IAM resource per CC VM. Set variable 
#    "reuse_iam" to true if you would like a single IAM profile created and 
#    assigned to ALL Cloud Connectors instead.
################################################################################
module "cc_iam" {
  source             = "../terraform-aws-cloud-connector-modules/modules/terraform-zscc-iam-aws"
  iam_count          = var.reuse_iam == false ? var.cc_count : 1
  name_prefix        = var.name_prefix
  resource_tag       = random_string.suffix.result
  global_tags        = local.global_tags
  secret_name        = var.secret_name
  cloud_tags_enabled = var.cloud_tags_enabled
}


################################################################################
# 6. Create Security Group and rules to be assigned to CC mgmt and and service 
#    interface(s). Default behavior will create 1 of each SG resource per CC VM. 
#    Set variable "reuse_security_group" to true if you would like a single 
#    security group created and assigned to ALL Cloud Connectors instead.
################################################################################
module "cc_sg" {
  source                   = "../terraform-aws-cloud-connector-modules/modules/terraform-zscc-sg-aws"
  sg_count                 = var.reuse_security_group == false ? var.cc_count : 1
  name_prefix              = var.name_prefix
  resource_tag             = random_string.suffix.result
  global_tags              = local.global_tags
  vpc_id                   = module.vpc.vpc_id
  zpa_enabled              = var.zpa_enabled
  http_probe_port          = var.http_probe_port
  mgmt_ssh_enabled         = var.mgmt_ssh_enabled
  gwlb_enabled             = false
  all_ports_egress_enabled = var.all_ports_egress_enabled
  support_access_enabled   = var.support_access_enabled
  zssupport_server         = var.zssupport_server
}


################################################################################
# 7. Create Route 53 Resolver Rules and Endpoints for utilization with DNS 
#    redirection to facilitate Cloud Connector ZPA service.
################################################################################



module "route53" {
  source                               = "../terraform-aws-cloud-connector-modules/modules/terraform-zscc-route53-aws"
  name_prefix                          = var.name_prefix
  resource_tag                         = random_string.suffix.result
  global_tags                          = local.global_tags
  vpc_id                               = module.vpc.vpc_id
  r53_subnet_ids                       = aws_subnet.cc_subnet[*].id
  outbound_endpoint_security_group_ids = module.cc_sg.outbound_endpoint_security_group_id
  domain_names                         = var.domain_names
  #target_address                      = var.target_address
  target_address                       = module.cc_vm.forwarding_ip
  depends_on = [module.cc_vm]
}


################################################################################
# Validation for Cloud Connector instance size and EC2 Instance Type 
# compatibilty. Terraform does not have a good/native way to raise an error at 
# the moment, so this will trigger off an invalid count value if there is an 
# improper deployment configuration.
################################################################################
resource "null_resource" "cc_error_checker" {
  count = local.valid_cc_create ? 0 : "Cloud Connector parameters were invalid. No appliances were created. Please check the documentation and cc_instance_size / ccvm_instance_type values that were chosen" # 0 means no error is thrown, else throw error
  provisioner "local-exec" {
    command = <<EOF
      echo "Cloud Connector parameters were invalid. No appliances were created. Please check the documentation and cc_instance_size / ccvm_instance_type values that were chosen" >> ../errorlog.txt
    EOF
  }
}
################################################################################
# Create default routes in private subnets pointing to the Cloud Connector
# in the same Availability Zone.
################################################################################

# 1. Use a data source to find the Cloud Connector instances based on the
#    tags that the cc_vm module is known to apply.
data "aws_instances" "cc_vms" {
  filter {
    name   = "tag:Name"
    values = [for i in range(var.cc_count) : "${var.name_prefix}-cc-vm-${i + 1}-${random_string.suffix.result}"]
  }

  # Ensure instances are running before we try to use them.
  instance_state_names = ["running"]

  # This is critical. The data source needs to run AFTER the instances
  # have been created and tagged by the module.
  depends_on = [module.cc_vm]
}

# 2. Use another data source to get the details of the network interfaces
#    that are attached to the instances we just found. We target the service
#    ENI, which is the first interface (device_index = 0).
data "aws_network_interface" "cc_service_enis" {
  count = length(data.aws_instances.cc_vms.ids)

  filter {
    name   = "attachment.instance-id"
    values = [data.aws_instances.cc_vms.ids[count.index]]
  }

  filter {
    name   = "attachment.device-index"
    values = ["0"] # The service interface is the first ENI (index 0)
  }
}

# 3. Create a simple map of {availability_zone -> network_interface_id}.
locals {
  cc_eni_by_az = {
    for eni in data.aws_network_interface.cc_service_enis : eni.availability_zone => eni.id
  }
}

# 4. Finally, create the routes. We loop through the VPC's private route
#    tables and use the AZ of each to look up the correct ENI from our map.
resource "aws_route" "private_default_to_cc" {
  count = length(module.vpc.private_route_table_ids)

  route_table_id         = module.vpc.private_route_table_ids[count.index]
  destination_cidr_block = "0.0.0.0/0"

  # Use the route table's AZ to find the correct ENI ID from the map.
  network_interface_id = local.cc_eni_by_az[module.vpc.azs[count.index]]
}