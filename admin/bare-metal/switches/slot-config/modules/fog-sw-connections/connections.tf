
terraform {
  required_version = ">= 0.14.0"
}

terraform {
  required_providers {
    junos = {
      source = "jeremmfr/junos"
    }
  }
}

variable machine_nr {
  type = number
}

variable slot {
  type = object({
    provisioning_vlan = number
    data_vlan         = number
  })
}

locals {

  # Shorthand
  n1_v_id   = var.slot.provisioning_vlan
  n2_v_id   = var.slot.data_vlan

  machine_name = format("Fog%02d", var.machine_nr)

  # Each 1GB Switch holds the connections for 18 Fog machines, in sequence of the
  # For machine number.  Thus Fog01 to Fog18 are connected to Switch 1, and Fog19
  # to Fog36 are connected to Switch 2. Each FoG machine's NIC 1 and NIC 2 are
  #  plugged into consecutive even/odd pairs of poarts on the switch.
  #
  # So:
  #
  # - Fog01 is plugged into ports 0 and 1 on Switch 1
  # - For02 is plugged into ports 2 and 3 on Switch 1
  # - Etc for Fog03 to Fog017
  # - For18 is plugged into ports 34 and 35 on Switch 1
  #
  # - Fog19 is plugged into ports 0 and 1 on Switch 2
  # - Etc for Fog20 to Fog36
  #
  # We get the Junos provider for the correct switch via our parent module invoking
  # us with the right provider specified.
  #
  # Use the machine number to compute the port# names (physical interface names) for
  # each of the two NICs.

  # (These are 1-origin indexes)
  switch_number      = floor((var.machine_nr + 17) / 18)
  position_on_switch = var.machine_nr - ((local.switch_number - 1) * 18)

  nic1_port_nr    = (local.position_on_switch - 1) * 2
  nic2_port_nr    = local.nic1_port_nr + 1

  nic1_port_name  = format("ge-0/0/%d", local.nic1_port_nr)
  nic2_port_name  = format("ge-0/0/%d", local.nic2_port_nr)

  # We want the ports to have a descirption reflecting the connected Fog machine NIC.

  nic1_port_descr = "${local.machine_name} - NIC 1"
  nic2_port_descr = "${local.machine_name} - NIC 2"

  # And, of course, a connection to the right VLAN.  But we need to do this in a way that
  # reflects that some VLANs are named in a different way in the switch config, eg.
  # VLAN 158 is named specially since it is a connection to the RH Network.

  nic1_vlan_name = local.n1_v_id == 158 ? "rh-network-158" : format("test-slot-vlan-%03d", local.n1_v_id)
  nic2_vlan_name = local.n2_v_id == 158 ? "rh-network-158" : format("test-slot-vlan-%03d", local.n2_v_id)
}

resource junos_interface_physical nic1_sw_port {
  name         = local.nic1_port_name
  description  = local.nic1_port_descr
  trunk        = false
  vlan_members = [local.nic1_vlan_name]
}

resource junos_interface_physical nic2_sw_port {
  name         = local.nic2_port_name
  description  = local.nic2_port_descr
  trunk        = false
  vlan_members = [local.nic2_vlan_name]
}
