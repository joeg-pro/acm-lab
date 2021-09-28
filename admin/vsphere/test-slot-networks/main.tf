
terraform {
  required_version = ">= 0.14.0"
}

locals {
   slot_list = concat([0, 1, 3], range(5, 24))
   slot_set = toset(formatlist("%02d", local.slot_list))
}

terraform {
  required_providers {
    vsphere = {
      version = "~> 2.0.0"
    }
  }
}

provider "vsphere" {
  user                 = local.vcenter_username
  password             = local.vcenter_password
  vsphere_server       = var.vcenter_server
  allow_unverified_ssl = true
}

data "vsphere_datacenter" "dc" {
  name = var.datacenter_name
}

data vsphere_distributed_virtual_switch pvt_network_dvs {
  name          = var.private_network_dvs_name
  datacenter_id = data.vsphere_datacenter.dc.id
}

module slot {
  for_each      = local.slot_set
  slot_nr       = each.key
  source        = "./modules/slot-networks"
  datacenter_id = data.vsphere_datacenter.dc.id
  dvs_id        = data.vsphere_distributed_virtual_switch.pvt_network_dvs.id
}

