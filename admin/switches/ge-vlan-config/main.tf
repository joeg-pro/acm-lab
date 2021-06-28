
# Defines VLAN, non-Fog port connections and inter-switch trunk connections.
# (Basically: Everything but the fog-machine-to-slot configs.)

terraform {
  required_version = ">= 0.15.0"
}

terraform {
  required_providers {
    junos = {
      source = "jeremmfr/junos"
    }
  }
}

provider junos {
  alias     = "sw_ge_1"
  ip        = "acm-2300-1g.mgmt.acm.lab.eng.rdu2.redhat.com"
  username  = var.switch_username
  password  = var.switch_password
}

provider junos {
  alias     = "sw_ge_2"
  ip        = "acm-2300-1g-2.mgmt.acm.lab.eng.rdu2.redhat.com"
  username  = var.switch_username
  password  = var.switch_password
}

locals {

  # Config constants.

  first_test_slot_nr = 0
  last_test_slot_nr  = 24

  base_test_slot_vlan_id = 200
  sw_ge_numbers = [1, 2]  # Add future switches 3, 4 to this list when future == now.


  #--- Specify the VLANs we want on each switch ---
  # (This config is applied across all switches.)

  # VLANs for test slots, named after slot:

  data_vlan_name_pattern  = "test-slot-%02d-data"
  data_vlan_descr_pattern = "Test slot %02d data network VLAN"

  prov_vlan_name_pattern  = "test-slot-%02d-prov"
  prov_vlan_descr_pattern = "Test slot %02d provisioning network VLAN"

  test_slot_data_vlans = {
    for sn in range(local.last_test_slot_nr+1):
      format(local.data_vlan_name_pattern, sn) => {
        id = local.base_test_slot_vlan_id + (sn * 2)
        description = format(local.data_vlan_descr_pattern, sn)
      }
  }

  test_slot_prov_vlans = {
    for sn in range(local.last_test_slot_nr+1):
      format(local.prov_vlan_name_pattern, sn) => {
        id = local.base_test_slot_vlan_id + (sn * 2) + 1
        description = format(local.prov_vlan_descr_pattern, sn)
      }
  }

  test_slot_vlans = merge(local.test_slot_data_vlans, local.test_slot_prov_vlans)

  # Other ad-hoc VLANs:

  rh_network_vlan_name = "rh-network-158"  # Derived from resource name below
  other_vlans = {
    rh-network-158 = {
      id = 158
      description = "Red Hat network 10.1.158.0 subnet VLAN"
    }
  }

  # Logic/variables for dealing with TF dependency issues when deleting VLAN.  Requires
  # multi-pass approach.  Set local.exclude_vlans to VLANs you want to delete and then
  # do a TF apply before changing config to actually remove the VLAN.  If not in a
  # VLAN-removal scenario, set local.exclude_vlans to an empty list.
  #
  # See the 10G switch TF config for additional info/whining about this.

  # exclude_vlans = ["pvt_net_vlan_352"]
  exclude_vlans = []

  # Local.all_vlan_defs holds definition info ror all VLANs, including the ones we are
  # trying to delete. Local.all_vlans is the subset of all_vlan_defs that excludes the
  # onces we are trying to delete and is the variable that should be the source of
  # VLAN defs for ports.

  all_vlan_defs = merge(local.test_slot_vlans, local.other_vlans)
  all_vlans = {
    for k,v in local.all_vlan_defs: k => {
      id = v.id
      description = v.description
    } if !contains(local.exclude_vlans, k)
  }
  all_vlan_names = [for k,v in local.all_vlans: replace(k, "_", "-")]

  non_excluded_test_slot_vlans = {
    for k,v in local.test_slot_vlans: k => {
      id = v.id
      description = v.description
    } if !contains(local.exclude_vlans, k)
  }
  non_excluded_test_slot_vlan_names = [for k,v in local.non_excluded_test_slot_vlans: replace(k, "_", "-")]

  # VSphere hosts get access to all active (non-excluded) test slot VLANs.
  # (Future: define additional variables for other classes of machines.)
  vlans_for_vsphere_hosts = local.non_excluded_test_slot_vlan_names

  # Contributes to the import_info output by import.sh:

  vlan_import_info_nested = [
    for n in local.sw_ge_numbers: [
      for v in local.all_vlan_names: {
        resource = format("junos_vlan.sw_ge_%d_vlan[\"%s\"]", n, v)
        id = replace(v, "_", "-")
      }
    ]
  ]
  vlan_import_info = flatten(local.vlan_import_info_nested)


  #--- Specify special machine connection to the switches  ---
  # (For machines other than the slot-related Fog machines)

  # VSphere Vapor and Mist hosts are connected into 1Gb Swithc 1 thusly:

  sw_ge_1_non_slot_machines = {
    mist_01 = {
      name  = "Mist01"  # Name of machine to use in description
      nics  = [2]       # The ordinal of the NICs connected (parallel to ports array)
      ports = [40]      # Ordinals of the switch ports to which NICs are connected
      vlans = local.vlans_for_vsphere_hosts   # VLANs to allow
    }
    mist_02 = {
      name  = "Mist02"
      nics  = [2]
      ports = [41]
      vlans = local.vlans_for_vsphere_hosts
    }
    mist_03 = {
      name  = "Mist03"
      nics  = [2]
      ports = [42]
      vlans = local.vlans_for_vsphere_hosts
    }
    mist_04 = {
      name  = "Mist04"
      nics  = [2]
      ports = [43]
      vlans = local.vlans_for_vsphere_hosts
    }
    mist_05 = {
      name  = "Mist05"
      nics  = [2]
      ports = [44]
      vlans = local.vlans_for_vsphere_hosts
    }
    vapor_01 = {
      name  = "Vapor01"
      nics  = [2]
      ports = [45]
      vlans = local.vlans_for_vsphere_hosts
    }
    vapor_02 = {
      name  = "Vapor02"
      nics  = [2]
      ports = [46]
      vlans = local.vlans_for_vsphere_hosts
    }
  }

  # Combine the above into config objecst we can for_each over.

  sw_ge_1_non_slot_machine_port_configs = flatten([
    for mn,mv in local.sw_ge_1_non_slot_machines: [
      for i in range(length(mv.ports)) : {
        port_name = format("ge-0/0/%s", mv.ports[i])
        description = format("%s -  1G NIC %d", mv.name, mv.nics[i])
        vlans = mv.vlans
      }
    ]
  ])

  # NB: No special machine connections into 1Gb siwtch 2.

  #--- Specify port configs for other special ports ---

  # There are a bunch of unused ports on the switches.

  sw_ge_1_unused_ports = [36, 37, 38, 39]
  sw_ge_2_unused_ports = [36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47]

  sw_ge_1_unused_port_configs = flatten([
    for pn in local.sw_ge_1_unused_ports: {
        port_name = format("ge-0/0/%s", pn)
        description = ""
        vlans = [local.rh_network_vlan_name]
    }
  ])

  sw_ge_2_unused_port_configs = flatten([
    for pn in local.sw_ge_2_unused_ports: {
        port_name = format("ge-0/0/%s", pn)
        description = ""
        vlans = [local.rh_network_vlan_name]
    }
  ])

  # Switch 1 has an uplink to RH network, and a connection to switch 2.

  sw_ge_1_special_port_configs = [
    {
      port_name = "ge-0/0/47"
      description = "Uplink to RH network 10.1.158.0 subnet"
      vlans = [local.rh_network_vlan_name]
    },
    {
      port_name = "xe-0/1/3"
      description = "Link to 1Gb switch 2"
      vlans = local.all_vlan_names
    }
  ]

  # And switch 2 has the other end of the connection from switch 1.

  sw_ge_2_special_port_configs = [
    {
      port_name = "xe-0/1/3"
      description = "Link to 1Gb switch 1"
      vlans = local.all_vlan_names
    }
  ]


  #--- Combine port config info ---

  # Combined the above stuff first into lists and then ultimately into
  # per-switch maps we can for-each over on each switch.

  sw_ge_1_port_configs = concat(
    local.sw_ge_1_non_slot_machine_port_configs,
    local.sw_ge_1_special_port_configs,
    local.sw_ge_1_unused_port_configs
  )
  sw_ge_1_ports = {
    for e in local.sw_ge_1_port_configs: e.port_name => {
       description = e.description
       vlans = e.vlans
    }
  }

  sw_ge_2_port_configs = concat(
    local.sw_ge_2_special_port_configs,
    local.sw_ge_2_unused_port_configs
  )
  sw_ge_2_ports = {
    for e in local.sw_ge_2_port_configs: e.port_name => {
       description = e.description
       vlans = e.vlans
    }
  }


  # Contribute import-info for each switch's config.

  combined_port_configs = {
    1: local.sw_ge_1_port_configs
    2: local.sw_ge_2_port_configs
  }

  port_import_info_nested = [
    for sw_nr,p_cfg in local.combined_port_configs: [
      for e in p_cfg : {
        resource = format("junos_interface_physical.sw_ge_%d_port[\"%s\"]", sw_nr, e.port_name)
        id = e.port_name
      }
    ]
  ]
  port_import_info = flatten(local.port_import_info_nested)

  # Combine all import info into a single thing referenced as an ooutput.

  import_info = concat(local.vlan_import_info, local.port_import_info)

}

# ======== Switch 1 ========

# VLANs:

resource junos_vlan sw_ge_1_vlan {

  provider = junos.sw_ge_1

  for_each = local.all_vlan_defs
    vlan_id     = each.value.id
    name        = replace(each.key, "_", "-")
    description = each.value.description
}

# Ports (Interfaces):

resource junos_interface_physical sw_ge_1_port {

  depends_on = [junos_vlan.sw_ge_1_vlan]

  provider = junos.sw_ge_1

  for_each = local.sw_ge_1_ports
    name         = each.key
    description  = each.value.description
    trunk        = length(each.value.vlans) > 1
    vlan_members = each.value.vlans
}

# ======== Switch 2 ========

# VLANs:

resource junos_vlan sw_ge_2_vlan {

  provider = junos.sw_ge_2

  for_each = local.all_vlan_defs
    vlan_id     = each.value.id
    name        = replace(each.key, "_", "-")
    description = each.value.description
}

# Ports (Interfaces):

resource junos_interface_physical sw_ge_2_port {

  depends_on = [junos_vlan.sw_ge_2_vlan]

  provider = junos.sw_ge_2

  for_each = local.sw_ge_2_ports
    name         = each.key
    description  = each.value.description
    trunk        = length(each.value.vlans) > 1
    vlan_members = each.value.vlans
}
