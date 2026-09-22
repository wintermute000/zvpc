################################################################################
# Outputs
################################################################################
output "vpc_id" {
  value = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  value = module.vpc.vpc_cidr_block
}

output "nat_public_ips_map" {
  description = "A map of public IPs where the key is the NAT GW ID and the value is the elastic IP."
  value = {
    for i, az in module.vpc.azs : az => {
      id         = module.vpc.natgw_ids[i]
      public_ip  = module.vpc.nat_public_ips[i]
    } if length(module.vpc.natgw_ids) > 0 # Only populate if NAT GWs were created
  }
}

output "public_subnet_id_map" {
  description = "A map of public subnets where the key is the subnet ID and the value is the CIDR block."
  value = {
    # Use a for loop with an index to map AZs to their corresponding subnet details
    for i, az in module.vpc.azs : az => {
      subnet_id  = module.vpc.public_subnets[i]
      cidr_block = module.vpc.public_subnets_cidr_blocks[i]
    }
  }
}

output "private_subnet_id_map" {
  description = "A map of private subnets where the key is the subnet ID and the value is the CIDR block."
  value = {
    # Use a for loop with an index to map AZs to their corresponding subnet details
    for i, az in module.vpc.azs : az => {
      subnet_id  = module.vpc.private_subnets[i]
      cidr_block = module.vpc.private_subnets_cidr_blocks[i]
    }
  }
}

output "cc_subnets_id_map" {
  description = "A map of Cloud Connector subnets, keyed by AZ, with their ID and CIDR block."
  value = {
    # Iterate over the list of subnet objects created by the resource.
    for subnet in aws_subnet.cc_subnet :

    # The key of the outer map is the subnet's Availability Zone.
    subnet.availability_zone =>

    # The value of the outer map is another map containing the desired details.
    {
      "cidr_block" = subnet.cidr_block
      "subnet_id"  = subnet.id
    }
  }
}

output "ssm_vpc_endpoint_ids" {
  description = "A map of the SSM interface endpoints, keyed by service name."
  value = {
    for service, endpoint in aws_vpc_endpoint.ssm : service => endpoint.id
  }
}

output "ssm_session_commands" {
  description = "Ready-to-run Session Manager commands for each workload, keyed by Availability Zone."
  value = {
    for az, instance in aws_instance.workloads :
    az => "aws ssm start-session --region ${var.aws_region} --target ${instance.id}"
  }
}

output "cloud_connector_ssm_session_commands" {
  description = "Ready-to-run Session Manager commands for each Cloud Connector, keyed by Availability Zone."
  value = {
    # Mirrors the indexing used by cloud_connector_details_by_az below.
    for i in range(length(module.cc_vm.id)) :
    module.cc_vm.availability_zone[i] => "aws ssm start-session --region ${var.aws_region} --target ${module.cc_vm.id[i]}"
  }
}

output "workload_details" {
  description = "A map of workload instances with their private IP and instance ID, keyed by Availability Zone."
  value = {
    # The 'for' loop is the same, but the value after '=>' is now an object {}
    for az, instance in aws_instance.workloads : az => {
      private_ip  = instance.private_ip
      instance_id = instance.id
    }
  }
}


output "cloud_connector_details_by_az" {
  description = "A map of all Cloud Connector VMs with their ID, Management IP, and Forwarding IP, keyed by Availability Zone."
  
  value = {
    # We will loop using an index 'i' from 0 up to the number of VMs created.
    # We use length() on one of the lists (e.g., id) to determine how many times to loop.
    for i in range(length(module.cc_vm.id)) :

    # The key for our map will be the Availability Zone at the current index 'i'.
    module.cc_vm.availability_zone[i] => {

      # The value will be an object containing the details from the other
      # lists, all referenced using the same index 'i'.
      id            = module.cc_vm.id[i]
      management_ip = module.cc_vm.management_ip[i]
      forwarding_ip = module.cc_vm.forwarding_ip[i]
    }
  }
}

