

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

variable ext_network_name {
  description = "Name of the virtual network/port group providing external connectivity."
  type = string
}

variable data_network_name {
  description = "Name the virtual network/port group serving as the internal datat network."
  type = string
}

variable prov_network_name {
  description = "Name the virtual network/port group serving as the internal datat network."
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

