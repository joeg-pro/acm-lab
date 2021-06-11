

variable vm_name {
  description = "Name of the VM."
  type = string
}

variable folder_path {
  description = "Path to folder in which to place the VM."
  type    = string
  default = ""
}

variable template_name {
  description = "Name of the template from which to clone the VM."
  type = string
}

variable slot_nr {
  description = "Ordinal number of the slot.  Passed to VM for config."
  type = number
}

variable nic1_network_name {
  description = "Name of the virtual network/port group to which NIC1 is to be connected."
  type = string
}

variable nic2_network_name {
  description = "Name the virtual network/port group to which NIC2 is to be connected."
  type = string
}

variable nic3_network_name {
  description = "Name the virtual network/port group to which NIC3 is to be connected."
  type = string
}

#--- VSphere Resources ---

variable datacenter_id {
  description = "Id of the vSphere datacenter in which to provision the VM."
  type = string
}

variable resource_pool_id {
  description = "Id of the resource pool in which to provision the VM."
  type = string
}

variable datastore_id {
  description = "Id of the vSphere datastore to hold the VM and its storage."
  type = string
}

