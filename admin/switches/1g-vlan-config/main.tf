
# Defines VLANs.
# TODO: Also defines trunk-mode connections and sets them to allow all vlans to flow.

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

variable switch_username {
  description = "Username to use to authenticate to the switches."
  type = string
}

variable switch_password {
  description = "Password to use to authenticate to the switches."
  type = string
}

provider junos {
  alias     = "sw1"
  ip        = "acm-2300-1g.mgmt.acm.lab.eng.rdu2.redhat.com"
  username  = var.switch_username
  password  = var.switch_password
}

provider junos {
  alias     = "sw2"
  ip        = "acm-2300-1g-2.mgmt.acm.lab.eng.rdu2.redhat.com"
  username  = var.switch_username
  password  = var.switch_password
}

locals {
  first_test_slot_vlan_id = 200
  last_test_slot_vlan_id  = 249

  test_slot_vlan_name_pfx  = "test-slot-vlan"
  test_slot_vlan_descr_pfx = "Test Slot VLAN"

  test_slot_vlan_ids = range(local.first_test_slot_vlan_id, local.last_test_slot_vlan_id+1)
  test_slot_vlan_set = toset([for i in local.test_slot_vlan_ids : tostring(i)])

  test_slot_vlan_names = [for i in local.test_slot_vlan_ids : "${local.test_slot_vlan_name_pfx}-${i}"]

  rh_network_vlan_name  = "rh-network-158"
  rh_network_vlan_descr = "Red Hat network VLAN"
  rh_network_vlan_id    = 158

  all_test_slot_vlan_names = local.test_slot_vlan_names
  all_vlan_names = concat(local.all_test_slot_vlan_names, [local.rh_network_vlan_name])
}


# ======== Switch 2 ========

resource junos_vlan sw1_test_slot_vlan {

  provider = junos.sw1

  for_each = local.test_slot_vlan_set

  name        = "${local.test_slot_vlan_name_pfx}-${each.key}"
  description = "${local.test_slot_vlan_descr_pfx} ${each.key}"
  vlan_id     = each.key
}

resource junos_vlan sw1_rh_network_vlan {

  provider = junos.sw1

  name        = local.rh_network_vlan_name
  description = local.rh_network_vlan_descr
  vlan_id     = local.rh_network_vlan_id
}

# Unused ports reserved for future special connections.

resource junos_interface_physical sw1_port_36 {

  provider = junos.sw1

  name         = "ge-0/0/36"
  description  = ""  # Not currently used
  trunk        = false
  vlan_members = [local.rh_network_vlan_name]
}

resource junos_interface_physical sw1_port_37 {

  provider = junos.sw1

  name         = "ge-0/0/37"
  description  = ""  # Not currently used
  trunk        = false
  vlan_members = [local.rh_network_vlan_name]
}

resource junos_interface_physical sw1_port_38 {

  provider = junos.sw1

  name         = "ge-0/0/38"
  description  = ""  # Not currently used
  trunk        = false
  vlan_members = [local.rh_network_vlan_name]
}

resource junos_interface_physical sw1_port_39 {

  provider = junos.sw1

  name         = "ge-0/0/39"
  description  = ""  # Not currently used
  trunk        = false
  vlan_members = [local.rh_network_vlan_name]
}

# Connections to Mist and Vapor machines.

resource junos_interface_physical sw1_port_40 {

  provider = junos.sw1

  name         = "ge-0/0/40"
  description  = "Mist01 - 1Gb NIC 2"
  trunk        = true
  vlan_members = local.all_test_slot_vlan_names
}

resource junos_interface_physical sw1_port_41 {

  provider = junos.sw1

  name         = "ge-0/0/41"
  description  = "Mist02 - 1Gb NIC 2"
  trunk        = true
  vlan_members = local.all_test_slot_vlan_names
}

resource junos_interface_physical sw1_port_42 {

  provider = junos.sw1

  name         = "ge-0/0/42"
  description  = "Mist03 - 1Gb NIC 2"
  trunk        = true
  vlan_members = local.all_test_slot_vlan_names
}

resource junos_interface_physical sw1_port_43 {

   provider = junos.sw1
   name         = "ge-0/0/43"
   description  = "Mist04 - 1Gb NIC 2"
   trunk        = true
   vlan_members = local.all_test_slot_vlan_names
}

resource junos_interface_physical sw1_port_44 {

  provider = junos.sw1

  name         = "ge-0/0/44"
  description  = "Mist05 - 1Gb NIC 2"
  trunk        = true
  vlan_members = local.all_test_slot_vlan_names
}

resource junos_interface_physical sw1_port_45 {

  provider = junos.sw1

  name         = "ge-0/0/45"
  description  = "Vapor01 - 1Gb NIC 2"
  trunk        = true
  vlan_members = local.all_test_slot_vlan_names
}

resource junos_interface_physical sw1_port_46 {

  provider = junos.sw1

  name         = "ge-0/0/46"
  description  = "Vapor02 - 1Gb NIC 2"
  trunk        = true
  vlan_members = local.all_test_slot_vlan_names
}

# Uplink to Red Hat network network 10.1.158.0/24 subnet.

resource junos_interface_physical sw1_port_47 {

  provider = junos.sw1

  name         = "ge-0/0/47"
  description  = "Uplink for RH 158 subnet"
  trunk        = false
  vlan_members = [local.rh_network_vlan_name]
}

# Connections to other switches.

resource junos_interface_physical sw1_10g_port_3 {

  provider = junos.sw1

  name         = "xe-0/1/3"
  description  = "Link to 1Gb switch 2"
  trunk        = true
  vlan_members = local.all_vlan_names
}


# ======== Switch 2 ========

resource junos_vlan sw2_test_slot_vlan {

  provider = junos.sw2

  for_each = local.test_slot_vlan_set

  name        = "${local.test_slot_vlan_name_pfx}-${each.key}"
  description = "${local.test_slot_vlan_descr_pfx} ${each.key}"
  vlan_id     = each.key
}

resource junos_vlan sw2_rh_network_vlan {

  provider = junos.sw2

  name        = local.rh_network_vlan_name
  description = local.rh_network_vlan_descr
  vlan_id     = local.rh_network_vlan_id
}

# Unused ports reserved for future special connections.

resource junos_interface_physical sw2_port_36 {

  provider = junos.sw2

  name         = "ge-0/0/36"
  description  = ""  # Not currently used
  trunk        = false
  vlan_members = [local.rh_network_vlan_name]
}

resource junos_interface_physical sw2_port_37 {

  provider = junos.sw2

  name         = "ge-0/0/37"
  description  = ""  # Not currently used
  trunk        = false
  vlan_members = [local.rh_network_vlan_name]
}

resource junos_interface_physical sw2_port_38 {

  provider = junos.sw2

  name         = "ge-0/0/38"
  description  = ""  # Not currently used
  trunk        = false
  vlan_members = [local.rh_network_vlan_name]
}

resource junos_interface_physical sw2_port_39 {

  provider = junos.sw2

  name         = "ge-0/0/39"
  description  = ""  # Not currently used
  trunk        = false
  vlan_members = [local.rh_network_vlan_name]
}

resource junos_interface_physical sw2_port_40 {

  provider = junos.sw2

  name         = "ge-0/0/40"
  description  = ""  # Not currently used
  trunk        = false
  vlan_members = [local.rh_network_vlan_name]
}

resource junos_interface_physical sw2_port_41 {

  provider = junos.sw2

  name         = "ge-0/0/41"
  description  = ""  # Not currently used
  trunk        = false
  vlan_members = [local.rh_network_vlan_name]
}

resource junos_interface_physical sw2_port_42 {

  provider = junos.sw2

  name         = "ge-0/0/42"
  description  = ""  # Not currently used
  trunk        = false
  vlan_members = [local.rh_network_vlan_name]
}

resource junos_interface_physical sw2_port_43 {

  provider = junos.sw2

  name         = "ge-0/0/43"
  description  = ""  # Not currently used
  trunk        = false
  vlan_members = [local.rh_network_vlan_name]
}

resource junos_interface_physical sw2_port_44 {

  provider = junos.sw2

  name         = "ge-0/0/44"
  description  = ""  # Not currently used
  trunk        = false
  vlan_members = [local.rh_network_vlan_name]
}

resource junos_interface_physical sw2_port_45 {

  provider = junos.sw2

  name         = "ge-0/0/45"
  description  = ""  # Not currently used
  trunk        = false
  vlan_members = [local.rh_network_vlan_name]
}

resource junos_interface_physical sw2_port_46 {

  provider = junos.sw2

  name         = "ge-0/0/46"
  description  = ""  # Not currently used
  trunk        = false
  vlan_members = [local.rh_network_vlan_name]
}

resource junos_interface_physical sw2_port_47 {

  provider = junos.sw2

  name         = "ge-0/0/47"
  description  = ""  # Not currently used
  trunk        = false
  vlan_members = [local.rh_network_vlan_name]
}

# Connections to other switches.

resource junos_interface_physical sw2_10g_port_3 {

  provider = junos.sw2

  name         = "xe-0/1/3"
  description  = "Link to 1Gb switch 1"
  trunk        = true
  vlan_members = local.all_vlan_names
}

