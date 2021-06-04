

variable "vcenter_server" {
  description = "Hostname of the vSphere server for the environment."
  type     = string
  default  = "10.1.158.10"
}

variable "datacenter_name" {
  description = "Name of the vSphere datacenter in whci to provision the networks."
  type    = string
  default = "ACM Lab Datacenter"
}

variable private_network_dvs_name {
  description = "Name of the VSphere Distributed Virtual Switch on which the slot private networks (port groups) are created."
  type    = string
  default = "Intra-Lab 1Gb dVSwitch"
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

