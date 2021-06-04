

variable datacenter_id {
  description = "Id of the vSphere datacenter in which to provision the networks."
  type = string
}

variable dvs_id {
  description = "Id of the VSphere Distributed Virtual Switch on which the slots private networks (port groups) are created."
  type = string
}

variable slot_nr {
  description = "Test slot number.  Used to compute VLAN ids and such."
  type = number
}

