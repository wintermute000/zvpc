variable "vpc_name" {
 type = string
 default = "zvpc"
 description = "VPC name"
}

variable "aws_region" {
 type = string
 default = "ap-southeast-2"
 description = "AWS region"
}

variable "cidr" {
 type = string
 default = "10.177.0.0/16"
 description = "VPC CIDR"
}

variable "azs" {
 type = list
 default = ["ap-southeast-2a", "ap-southeast-2b"]
 description = "Availability Zones"
}

variable "public_subnets" {
 type = list
 default = ["10.177.1.0/24", "10.177.2.0/24"]
 description = "Public Subnets"
}

variable "private_subnets" {
 type = list
 default = ["10.177.11.0/24", "10.177.12.0/24"]
 description = "Private Subnets"
}

variable "owner_tag" {
 type = string
 default = "johannlo"
 description = "owner"
}

variable "global_tags" {
  type        = map(string)
  description = "Populate any custom user defined tags from a map"
  default     = {}
}

variable "name_prefix" {
 type = string
 default = "zvpc"
 description = "owner"
}

variable "keypair" {
 type = string
 default = "keypair-zscaler-aws"
 description = "AWS SSH Key Pair"
}

variable "workload_nsg_source_prefix" {
  type        = list(string)
  description = "CIDR blocks of trusted networks for workload host ssh access"
  default     = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
}

variable "iam_role_policy_ssmcore" {
  type        = string
  description = "AWS EC2 Instance predefined IAM Role to access AWS SSM"
  default     = "AmazonSSMManagedInstanceCore"
}

variable "ac_count" {
  type        = number
  description = "Default number of App Connector appliances to create"
  default     = 2
}

variable "acvm_instance_type" {
  type        = string
  description = "App Connector Instance Type"
  default     = "m5.large"
  validation {
    condition = (
      var.acvm_instance_type == "t3.medium" ||
      var.acvm_instance_type == "t3.large" ||
      var.acvm_instance_type == "t3.xlarge" ||
      var.acvm_instance_type == "t3a.medium" ||
      var.acvm_instance_type == "t3a.large" ||
      var.acvm_instance_type == "t3a.xlarge" ||
      var.acvm_instance_type == "t3a.2xlarge" ||
      var.acvm_instance_type == "m5.large" ||
      var.acvm_instance_type == "m5.xlarge" ||
      var.acvm_instance_type == "m5.2xlarge" ||
      var.acvm_instance_type == "m5.4xlarge" ||
      var.acvm_instance_type == "m5a.large" ||
      var.acvm_instance_type == "m5a.xlarge" ||
      var.acvm_instance_type == "m5a.2xlarge" ||
      var.acvm_instance_type == "m5a.4xlarge" ||
      var.acvm_instance_type == "m5n.large" ||
      var.acvm_instance_type == "m5n.xlarge" ||
      var.acvm_instance_type == "m5n.2xlarge" ||
      var.acvm_instance_type == "m5n.4xlarge" ||
      var.acvm_instance_type == "t2.micro" #This is only recommended for lab/testing purposes and only works with Amazon Linux 2 AMIs. Zscaler AMI does not support t2.micro
    )
    error_message = "Input acvm_instance_type must be set to an approved vm instance type."
  }
}

variable "workload_instance_type" {
  type        = string
  description = "The workload host EC2 instance type"
  default     = "t3.micro"
}

variable "reuse_security_group" {
  type        = bool
  description = "Specifies whether the SG module should create 1:1 security groups per instance or 1 security group for all instances"
  default     = false
}

variable "reuse_iam" {
  type        = bool
  description = "Specifies whether the SG module should create 1:1 IAM per instance or 1 IAM for all instances"
  default     = false
}

variable "associate_public_ip_address" {
  default     = false
  type        = bool
  description = "enable/disable public IP addresses on App Connector instances. Setting this to true will result in the following: Dynamic Public IP address on the App Connector VM Instance will be enabled; no EIP or NAT Gateway resources will be created; and the App Connector Route Table default route next-hop will be set as the IGW"
}

variable "use_zscaler_ami" {
  default     = true
  type        = bool
  description = "By default, App Connector will deploy via the Zscaler Latest AMI. Setting this to false will deploy the latest Amazon Linux 2 AMI instead"
}

variable "ami_id" {
  type        = list(string)
  description = "AMI ID(s) to be used for deploying App Connector appliances. Ideally all VMs should be on the same AMI ID as templates always pull the latest from AWS Marketplace. This variable is provided if a customer desires to override/retain an old ami for existing deployments rather than upgrading and forcing a replacement. It is also inputted as a list to facilitate if a customer desired to manually upgrade select ACs deployed based on the ac_count index"
  default     = [""]
}

# ZPA Provider specific variables for App Connector Group and Provisioning Key creation
variable "byo_provisioning_key" {
  type        = bool
  description = "Bring your own App Connector Provisioning Key. Setting this variable to true will effectively instruct this module to not create any resources and only reference data resources from values provided in byo_provisioning_key_name"
  default     = false
}

variable "byo_provisioning_key_name" {
  type        = string
  description = "Existing App Connector Provisioning Key name"
  default     = "provisioning-key-tf"
}

variable "enrollment_cert" {
  type        = string
  description = "Get name of ZPA enrollment cert to be used for App Connector provisioning"
  default     = "Connector"

  validation {
    condition = (
      var.enrollment_cert == "Connector"
    )
    error_message = "Input enrollment_cert must be set to an approved value."
  }
}

variable "app_connector_group_description" {
  type        = string
  description = "Optional: Description of the App Connector Group"
  default     = "This App Connector Group belongs to: "
}

variable "app_connector_group_enabled" {
  type        = bool
  description = "Whether this App Connector Group is enabled or not"
  default     = true
}

variable "app_connector_group_country_code" {
  type        = string
  description = "Optional: Country code of this App Connector Group. example 'US'"
  default     = "US"
}

variable "app_connector_group_latitude" {
  type        = string
  description = "Latitude of the App Connector Group. Integer or decimal. With values in the range of -90 to 90"
  default     = "37.33874"
}

variable "app_connector_group_longitude" {
  type        = string
  description = "Longitude of the App Connector Group. Integer or decimal. With values in the range of -90 to 90"
  default     = "-121.8852525"
}

variable "app_connector_group_location" {
  type        = string
  description = "location of the App Connector Group in City, State, Country format. example: 'San Jose, CA, USA'"
  default     = "San Jose, CA, USA"
}

variable "app_connector_group_upgrade_day" {
  type        = string
  description = "Optional: App Connectors in this group will attempt to update to a newer version of the software during this specified day. Default value: SUNDAY. List of valid days (i.e., SUNDAY, MONDAY, etc)"
  default     = "SUNDAY"
}

variable "app_connector_group_upgrade_time_in_secs" {
  type        = string
  description = "Optional: App Connectors in this group will attempt to update to a newer version of the software during this specified time. Default value: 66600. Integer in seconds (i.e., 66600). The integer should be greater than or equal to 0 and less than 86400, in 15 minute intervals"
  default     = "66600"
}

variable "app_connector_group_override_version_profile" {
  type        = bool
  description = "Optional: Whether the default version profile of the App Connector Group is applied or overridden. Default: false"
  default     = true
}

variable "app_connector_group_version_profile_id" {
  type        = string
  description = "Optional: ID of the version profile. To learn more, see Version Profile Use Cases. https://help.zscaler.com/zpa/configuring-version-profile"
  default     = "0"

  validation {
    condition = (
      var.app_connector_group_version_profile_id == "0" || #Default = 0
      var.app_connector_group_version_profile_id == "1" || #Previous Default = 1
      var.app_connector_group_version_profile_id == "2"    #New Release = 2
    )
    error_message = "Input app_connector_group_version_profile_id must be set to an approved value."
  }
}

variable "app_connector_group_dns_query_type" {
  type        = string
  description = "Whether to enable IPv4 or IPv6, or both, for DNS resolution of all applications in the App Connector Group"
  default     = "IPV4_IPV6"

  validation {
    condition = (
      var.app_connector_group_dns_query_type == "IPV4_IPV6" ||
      var.app_connector_group_dns_query_type == "IPV4" ||
      var.app_connector_group_dns_query_type == "IPV6"
    )
    error_message = "Input app_connector_group_dns_query_type must be set to an approved value."
  }
}

variable "provisioning_key_enabled" {
  type        = bool
  description = "Whether the provisioning key is enabled or not. Default: true"
  default     = true
}

variable "provisioning_key_association_type" {
  type        = string
  description = "Specifies the provisioning key type for App Connectors or ZPA Private Service Edges. The supported values are CONNECTOR_GRP and SERVICE_EDGE_GRP"
  default     = "CONNECTOR_GRP"

  validation {
    condition = (
      var.provisioning_key_association_type == "CONNECTOR_GRP"
    )
    error_message = "Input provisioning_key_association_type must be set to an approved value."
  }
}

variable "provisioning_key_max_usage" {
  type        = number
  description = "The maximum number of instances where this provisioning key can be used for enrolling an App Connector or Service Edge"
  default     = 10
}

variable "cc_vm_prov_url" {
  type        = string
  description = "Zscaler Cloud Connector Provisioning URL"
}

variable "secret_name" {
  type        = string
  description = "AWS Secrets Manager Secret Name for Cloud Connector provisioning"
  default = "Zscaler_Cloud_Connector_Secret"
}

variable "http_probe_port" {
  type        = number
  description = "Port number for Cloud Connector cloud init to enable listener port for HTTP probe from GWLB Target Group"
  default     = 50000
  validation {
    condition = (
      tonumber(var.http_probe_port) == 80 ||
      (tonumber(var.http_probe_port) >= 1024 && tonumber(var.http_probe_port) <= 65535)
    )
    error_message = "Input http_probe_port must be set to a single value of 80 or any number between 1024-65535."
  }
}

variable "ccvm_instance_type" {
  type        = string
  description = "Cloud Connector Instance Type"
  default     = "m6i.large"
  validation {
    condition = (
      var.ccvm_instance_type == "t3.medium" ||
      var.ccvm_instance_type == "m5n.large" ||
      var.ccvm_instance_type == "c5a.large" ||
      var.ccvm_instance_type == "m6i.large" ||
      var.ccvm_instance_type == "c6i.large" ||
      var.ccvm_instance_type == "c6in.large" ||
      var.ccvm_instance_type == "m5n.4xlarge" ||
      var.ccvm_instance_type == "m6i.4xlarge" ||
      var.ccvm_instance_type == "c6i.4xlarge" ||
      var.ccvm_instance_type == "c6in.4xlarge"
    )
    error_message = "Input ccvm_instance_type must be set to an approved vm instance type."
  }
}

variable "cc_instance_size" {
  type        = string
  description = "Cloud Connector Instance size. Determined by and needs to match the Cloud Connector Portal provisioning template configuration"
  default     = "small"
  validation {
    condition = (
      var.cc_instance_size == "small" ||
      var.cc_instance_size == "medium" ||
      var.cc_instance_size == "large"
    )
    error_message = "Input cc_instance_size must be set to an approved cc instance type."
  }
}

locals {
  small_cc_instance  = ["t3.medium", "m5n.large", "c5a.large", "m6i.large", "c6i.large", "c6in.large", "m5n.4xlarge", "m6i.4xlarge", "c6i.4xlarge", "c6in.4xlarge"]
  medium_cc_instance = ["m5n.4xlarge", "m6i.4xlarge", "c6i.4xlarge", "c6in.4xlarge"]
  large_cc_instance  = ["m5n.4xlarge", "m6i.4xlarge", "c6i.4xlarge", "c6in.4xlarge"]

  valid_cc_create = (
    contains(local.small_cc_instance, var.ccvm_instance_type) && var.cc_instance_size == "small" ||
    contains(local.medium_cc_instance, var.ccvm_instance_type) && var.cc_instance_size == "medium" ||
    contains(local.large_cc_instance, var.ccvm_instance_type) && var.cc_instance_size == "large"
  )
}

variable "cc_count" {
  type        = number
  description = "Default number of Cloud Connector appliances to create"
  default     = 2
}

variable "domain_names" {
  type        = map(any)
  description = "Domain names fqdn/wildcard to have Route 53 redirect DNS requests to Cloud Connector for ZPA. Refer to terraform.tfvars ZPA/Route 53 specific variables"
  default = { appseg1: "planetexpress.com.au", appseg2: "mrderp.com.au", }
}

variable "target_address" {
  type        = list(string)
  description = "Route 53 DNS queries will be forwarded to these Zscaler Global VIP addresses"
  default     = ["185.46.212.88", "185.46.212.89"]
}

variable "zpa_enabled" {
  type        = bool
  default     = true
  description = "Configure Route 53 Subnets, Route Tables, and Resolvers for ZPA DNS redirection with route53 module"
}

variable "ccami_id" {
  type        = list(string)
  description = "AMI ID(s) to be used for deploying Cloud Connector appliances. Ideally all VMs should be on the same AMI ID as templates always pull the latest from AWS Marketplace. This variable is provided if a customer desires to override/retain an old ami for existing deployments rather than upgrading and forcing a replacement. It is also inputted as a list to facilitate if a customer desired to manually upgrade select CCs deployed based on the cc_count index"
  default     = [""]
}

variable "mgmt_ssh_enabled" {
  type        = bool
  description = "Default is true which creates an ingress rule permitting SSH traffic from the local VPC to the CC management interface. If false, the rule is not created. Value ignored if not creating a security group"
  default     = true
}

variable "all_ports_egress_enabled" {
  type        = bool
  default     = true
  description = "Default is true which creates an egress rule permitting the CC service interface to forward direct traffic on all ports and protocols. If false, the rule is not created. Value ignored if not creating a security group"
}

variable "ebs_volume_type" {
  type        = string
  description = "(Optional) Type of volume. Valid values include standard, gp2, gp3, io1, io2, sc1, or st1. Defaults to gp3"
  default     = "gp3"
}

variable "ebs_encryption_enabled" {
  type        = bool
  description = "true/false whether to enable EBS encryption on the root volume. Default is true"
  default     = true
}

variable "byo_kms_key_alias" {
  type        = string
  description = "Requires var.ebs_encryption_enabled to be true. Set to null by default which is the AWS default managed/master key. Set as 'alias/<key-alias>' to use a custom KMS key"
  default     = null
}

variable "cloud_tags_enabled" {
  type        = bool
  description = "Determines whether or not to create the cc_tags_policy IAM Policy and attach it to the CC IAM Role"
  default     = false
}

variable "support_access_enabled" {
  type        = bool
  description = "If Network Security Group is being configured, enable a specific outbound rule for Cloud Connector to be able to establish connectivity for Zscaler support access. Default is true"
  default     = true
}

variable "zssupport_server" {
  type        = string
  description = "destination IP address of Zscaler Support access server. IP resolution of remotesupport.<zscaler_customer_cloud>.net"
  default     = "199.168.148.101/32" #for commercial clouds
}

variable "hostname_type" {
  type        = string
  description = "Type of hostname for Cloud Connector instances"
  default     = "resource-name"

  validation {
    condition = (
      var.hostname_type == "resource-name" ||
      var.hostname_type == "ip-name"
    )
    error_message = "Input hostname_type must be set to either resource-name or ip-name."
  }
}

variable "resource_name_dns_a_record_enabled" {
  type        = bool
  description = "Indicates whether to respond to DNS queries for instance hostnames with DNS A records. Default is false"
  default     = false
}