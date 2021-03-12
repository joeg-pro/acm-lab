
terraform {
  required_version = ">= 0.14.0"
}


variable provisioning_vlan {
  type = number
}

variable data_vlan {
  type = number
}

locals {
   slot = {
     provisioning_vlan = var.provisioning_vlan
     data_vlan         = var.data_vlan
   }
}

output slot {
  value = local.slot
}

