
variable gap_template_name {
  description = "Name of template to use to create the GAP VM, or latest."
  type    = string
  default = "latest"
}

variable gap_template_pattern {
  description = "Template name pattern used to find latest version."
  type    = string
  default = "vm/VM Templates/Base-RHEL-8-GAP"
}

variable slot_list {
  description = "List of slot numbers for whihc a GAP VM is to be provisioned."
  type = list(number)
}

# VCenter Resources

variable vcenter_server {
  description = "Hostname of the vSphere server for the environment."
  type     = string
  default  = "10.1.158.10"
}

variable datacenter_name {
  description = "Name of the vSphere datacenter in whci to provision the networks."
  type    = string
  default = "ACM Lab Datacenter"
}

variable cluster_name {
  description = "Name of the vSphere cluster in which to provision the GAP VMs."
  type    = string
  default = "Workload Cluster"
}

variable datastore_name {
  description = "Name of the vSphere datastore to hold the GAP VMs."
  type    = string
  default = "Mist_Workload_B"
}

variable slot_folder_root {
  description = "VSphere folder in which to create slot-specific folders"
  type    = string
  default = "Test Slot Infrastructure"
}

# -- Credentials ---

variable "vcenter_user_file" {
  description = "Path to file containing username to use to authenticate to vSphere server."
  type = string
  default = ""
}

variable "vcenter_password_file" {
  description = "Path to file containing password to use to authenticate to vSphere server."
  type = string
  default = ""
}

# Inline version of credentials:
# Intended for use in build automation, not recommended for ad-hoc use

variable "vcenter_user" {
  description = "Username to use to authenticate to vSphere server."
  # if an empty string, config will read contents of file specified in var.vcenter_user_file
  type = string
  sensitive = true
  default = ""
}

variable "vcenter_password" {
  description = "Password to use to authenticate to vSphere server."
  # if an empty string, config will read contents of file specified in var.vcenter_password_file
  type = string
  sensitive = true
  default = ""
}

