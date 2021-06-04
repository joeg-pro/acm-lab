# Note:

# Strictly speaking, promiscious mode and forgetd transmits are only needed when the slot
#is used for Bare Metal IPI, as these are only needed to have the nesterd virt of the
# bootstrap (libvirt) VM in the GAP VM work.  Setting promiscious mode on does have a
# downside as it causes the GAP VM to get extra traffic which the stack in the VM must
# then filter out).  But we'll always turn it on anyway to keep the test slot configs
# uniform for now.

locals {

  data_network_vlan_number  = 200 + (var.slot_nr * 2)
  prov_network_vlan_number  = local.data_network_vlan_number + 1

  two_digit_slot_number = format("%02d", var.slot_nr)
}

resource vsphere_distributed_port_group data_network {

  distributed_virtual_switch_uuid = var.dvs_id

  name        = "Test Slot ${local.two_digit_slot_number} Data Network"
  description = "Private layer 2 data network for Test Slot ${local.two_digit_slot_number} (VLAN ${local.data_network_vlan_number}).  Security controls on this port group must allow promiscuous mode and forged transmits."
  vlan_id     = local.data_network_vlan_number

  allow_promiscuous      = true
  allow_forged_transmits = true
}

resource vsphere_distributed_port_group prov_network {

  distributed_virtual_switch_uuid = var.dvs_id

  name        = "Test Slot ${local.two_digit_slot_number} Provisioning Network"
  description = "Private layer 2 provisioning network for Test Slot ${local.two_digit_slot_number} (VLAN ${local.data_network_vlan_number}).  Security controls on this port group must allow promiscuous mode and forged transmits."
  vlan_id     = local.prov_network_vlan_number

  allow_promiscuous      = true
  allow_forged_transmits = true

  # These are enabled by defualt if you create the port group in the VCenter UI.

  block_override_allowed          = true
  port_config_reset_at_disconnect = true
}

