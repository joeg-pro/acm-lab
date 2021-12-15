
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
  # First switch in rack A36

  alias     = "sw_ge_1"
  ip        = "acm-2300-1g.mgmt.acm.lab.eng.rdu2.redhat.com"
  username  = var.switch_username
  password  = var.switch_password
}

provider junos {
  # Second switch in rack A36

  alias     = "sw_ge_2"
  ip        = "acm-2300-1g-2.mgmt.acm.lab.eng.rdu2.redhat.com"
  username  = var.switch_username
  password  = var.switch_password
}

provider junos {
  # First (only) switch in rack A37

  alias     = "sw_ge_3"
  ip        = "acm-2300-1g-3.mgmt.acm.lab.eng.rdu2.redhat.com"
  username  = var.switch_username
  password  = var.switch_password
}

provider junos {
  # First (only) switch in rack A38

  alias     = "sw_ge_4"
  ip        = "acm-2300-1g-4.mgmt.acm.lab.eng.rdu2.redhat.com"
  username  = var.switch_username
  password  = var.switch_password
}

provider junos {
  # First (only) switch in rack A35. Acts as "root" switch.
  # Note: Switch 5 has no slot-resident machines connected to it, so there is no
  # further config for it in this TF.  But the provider is defined keep it handy.

  alias     = "sw_ge_5"
  ip        = "acm-2300-1g-5.mgmt.acm.lab.eng.rdu2.redhat.com"
  username  = var.switch_username
  password  = var.switch_password
}

#=== Configuration Info ===

locals {

  # Machine to slot assignment:

  # Note: Every machine needs to be assigned to some slot. Slot 49 is the
  # "in the garage for maintenance" slot so assign to that if unused.

  machine_slot_assignments = {
    00 = ["fog_01", "fog_02", "fog_03", "fog_04", "fog_05", "fog_06"],
    02 = ["fog_07", "fog_08", "fog_09", "fog_10", "fog_11", "fog_12"],
    04 = ["fog_13", "fog_14", "fog_15", "fog_16", "fog_17", "fog_18"],
    06 = ["fog_19", "fog_20", "fog_21", "fog_22", "fog_23", "fog_24"],
    08 = ["fog_25", "fog_26", "fog_27", "fog_28", "fog_29", "fog_30"],
    49 = ["fog_31", "fog_32", "fog_33", "fog_34", "fog_35", "fog_36",
          "fog_37", "fog_38", "fog_39", "fog_40", "fog_41", "fog_42",
          "fog_43", "fog_44", "fog_45", "fog_46", "fog_47", "fog_48",
          "fog_49", "fog_50", "fog_51"]

  }

  unallocated_machines = ""

  # Machine NIC to switch port configuration:

  sw_ge_1_machine_connections = {
    fog_01 = {
      name  = "Fog01"   # Name of machine to use in description
      nics  = [1, 2]    # The ordinal of the NICs connected (parallel to ports array)
      ports = [0, 1]    # Ordinals of the switch ports to which NICs are connected
    },
    fog_02 = {name="Fog02", nics=[1, 2], ports=[2, 3]},
    fog_03 = {name="Fog03", nics=[1, 2], ports=[4, 5]},
    fog_04 = {name="Fog04", nics=[1, 2], ports=[6, 7]},
    fog_05 = {name="Fog05", nics=[1, 2], ports=[8, 9]},
    fog_06 = {name="Fog06", nics=[1, 2], ports=[10, 11]},
    fog_07 = {name="Fog07", nics=[1, 2], ports=[12, 13]},
    fog_08 = {name="Fog08", nics=[1, 2], ports=[14, 15]},
    fog_09 = {name="Fog09", nics=[1, 2], ports=[16, 17]},
    fog_10 = {name="Fog10", nics=[1, 2], ports=[18, 19]},
    fog_11 = {name="Fog11", nics=[1, 2], ports=[20, 21]},
    fog_12 = {name="Fog12", nics=[1, 2], ports=[22, 23]},
    fog_13 = {name="Fog13", nics=[1, 2], ports=[24, 25]},
    fog_14 = {name="Fog14", nics=[1, 2], ports=[26, 27]},
    fog_15 = {name="Fog15", nics=[1, 2], ports=[28, 29]},
    fog_16 = {name="Fog16", nics=[1, 2], ports=[30, 31]},
    fog_17 = {name="Fog17", nics=[1, 2], ports=[32, 33]},
    fog_18 = {name="Fog18", nics=[1, 2], ports=[34, 35]}
  }

  sw_ge_2_machine_connections = {
    fog_19 = {name="Fog19", nics=[1, 2], ports=[0, 1]},
    fog_20 = {name="Fog20", nics=[1, 2], ports=[2, 3]},
    fog_21 = {name="Fog21", nics=[1, 2], ports=[4, 5]},
    fog_22 = {name="Fog22", nics=[1, 2], ports=[6, 7]},
    fog_23 = {name="Fog23", nics=[1, 2], ports=[8, 9]},
    fog_24 = {name="Fog24", nics=[1, 2], ports=[10, 11]}
  }

  sw_ge_3_machine_connections = {
    fog_25 = {name="Fog25", nics=[1, 2], ports=[0, 1]},
    fog_26 = {name="Fog26", nics=[1, 2], ports=[2, 3]},
    fog_27 = {name="Fog27", nics=[1, 2], ports=[4, 5]},
    fog_28 = {name="Fog28", nics=[1, 2], ports=[6, 7]},
    fog_29 = {name="Fog29", nics=[1, 2], ports=[8, 9]},
    fog_30 = {name="Fog30", nics=[1, 2], ports=[10, 11]},
    fog_31 = {name="Fog31", nics=[1, 2], ports=[12, 13]},
    fog_32 = {name="Fog32", nics=[1, 2], ports=[14, 15]},
    fog_33 = {name="Fog33", nics=[1, 2], ports=[16, 17]},
    fog_34 = {name="Fog34", nics=[1, 2], ports=[18, 19]},
    fog_35 = {name="Fog35", nics=[1, 2], ports=[20, 21]},
    fog_36 = {name="Fog36", nics=[1, 2], ports=[22, 23]},
    fog_37 = {name="Fog37", nics=[1, 2], ports=[24, 25]},
    fog_38 = {name="Fog38", nics=[1, 2], ports=[26, 27]},
    fog_39 = {name="Fog39", nics=[1, 2], ports=[28, 29]},
    fog_40 = {name="Fog40", nics=[1, 2], ports=[30, 31]},
    fog_41 = {name="Fog41", nics=[1, 2], ports=[32, 33]},
    fog_42 = {name="Fog42", nics=[1, 2], ports=[34, 35]}
  }

  sw_ge_4_machine_connections = {
    fog_43 = {name="Fog43", nics=[1, 2], ports=[0, 1]},
    fog_44 = {name="Fog44", nics=[1, 2], ports=[2, 3]},
    fog_45 = {name="Fog45", nics=[1, 2], ports=[4, 5]},
    fog_46 = {name="Fog46", nics=[1, 2], ports=[6, 7]},
    fog_47 = {name="Fog47", nics=[1, 2], ports=[8, 9]},
    fog_48 = {name="Fog48", nics=[1, 2], ports=[10, 11]},
    fog_49 = {name="Fog49", nics=[1, 2], ports=[12, 13]},
    fog_50 = {name="Fog50", nics=[1, 2], ports=[14, 15]},
    fog_51 = {name="Fog51", nics=[1, 2], ports=[16, 17]}
  }

  # Note: Add map entries to local.machine_connections for any new switches.

  machine_connections = {
    sw_ge_1 = local.sw_ge_1_machine_connections
    sw_ge_2 = local.sw_ge_2_machine_connections
    sw_ge_3 = local.sw_ge_3_machine_connections
    sw_ge_4 = local.sw_ge_4_machine_connections
  }

}

#=== "Compile it" Locals ===

locals {

  #----------------------------------------------------------------------
  # "Compile" slot assignment/machine-connection info into usable form.
  #----------------------------------------------------------------------

  # Convert the slot-assignemnt and machine-connection info in local vars into
  # a map of maps we can for_each over within per-switch junos_physcial_interface
  # resources to define the switch port/interface configuration.

  # (We do this stepwide to assist in debugging/understanding, maybe.)

  # First, use the slot assinment info to produce an augmented machine connection map
  # ("machine connections extended") that adds vlan info into the name, port etc. info
  # defined in the base map.

  machine_to_slot_nr_map = transpose(local.machine_slot_assignments)
  machine_connections_ext = {
    # (Iteration vars: sw_n = switch name, sw_mc = sw_n's machine connections)
    for sw_n,sw_mc in local.machine_connections: sw_n => {
      # (Iteration vars: mn = machine key/id, mv = info about machine mn)
      for mk,mv in local.machine_connections[sw_n]: mk => {
        name  = mv.name, nics  = mv.nics, ports = mv.ports
        vlans = [
          for i in range(length(mv.ports)):
            # Map to slot's provisioning/data VLAN name based on what NIC it is:
            mv.nics[i] == 1 ?
              format("test-slot-%02d-prov", tonumber(local.machine_to_slot_nr_map[mk][0])) :
              format("test-slot-%02d-data", tonumber(local.machine_to_slot_nr_map[mk][0]))
        ]
      }
    }
  }

  # We now need to convert from machine_connections_ext's map-of-maps where the inner
  # map has one entry per machine into a map-of-maps where the inner map has one entry
  # per port to be configured on that switch.  It seems not possible to do this in one
  # fell swoop because doing that would require the key expression for the inner map to
  #  be insdie a nested for, which TF doesn't seem to like.  So instead we do this
  # in a couple of steps.  (This approach inspired by this GH issue command and related
  # discussion: https://github.com/hashicorp/terraform/issues/22263#issuecomment-581205359)

  # So, convert the machine_connections_ext into a map from switch-name to a list of
  # port config info to be applied to that switch, using flatten() to flatten out
  # the nesting of the map-value list.

  spc_intermediate_map_of_lists = {
    for sw_n,sw_mc in local.machine_connections_ext: sw_n => flatten([
      for mn,mv in sw_mc: [
        for i in range(length(mv.ports)): {
          key = format("ge-0/0/%s", mv.ports[i])
          value = {
            description = format("%s 1G NIC %d", mv.name, mv.nics[i])
            vlans = [sw_mc[mn].vlans[i]]
          }
        }
      ]
    ])
  }

  # And now  finally convert the above into the map of maps we'll use to
  # for-each in the per-switch junos.physcial_interface resources.

  switch_port_configs = {
    for sw_n,sw_pcl in local.spc_intermediate_map_of_lists: sw_n => {
      for e in sw_pcl: e.key =>  e.value
    }
  }

  #----------------------------------------------
  # Collect up import_info for use by import.sh
  #----------------------------------------------

  # Contributes to the import_info output for use by import.sh:
  switch_port_import_info = flatten([
    for sw_n,sw_pcm in local.switch_port_configs: [
      for pn,pc in sw_pcm: {
        resource = format("junos_interface_physical.%s_port[\"%s\"]", sw_n, pn)
        id = pn
      }
    ]
  ])

  import_info = local.switch_port_import_info
}


# ======== Switch 1 ========

resource junos_interface_physical sw_ge_1_port {

  provider = junos.sw_ge_1

  for_each = local.switch_port_configs["sw_ge_1"]
    name         = each.key
    description  = each.value.description
    trunk        = length(each.value.vlans) > 1
    vlan_members = each.value.vlans
    ether_opts {
      auto_negotiation    = true
      flow_control        = false
      loopback            = false
      no_auto_negotiation = false
      no_flow_control     = false
      no_loopback         = false
    }
}

# ======== Switch 2 ========

resource junos_interface_physical sw_ge_2_port {

  provider = junos.sw_ge_2

  for_each = local.switch_port_configs["sw_ge_2"]
    name         = each.key
    description  = each.value.description
    trunk        = length(each.value.vlans) > 1
    vlan_members = each.value.vlans
    ether_opts {
      auto_negotiation    = true
      flow_control        = false
      loopback            = false
      no_auto_negotiation = false
      no_flow_control     = false
      no_loopback         = false
    }
}

# ======== Switch 3 ========

resource junos_interface_physical sw_ge_3_port {

  provider = junos.sw_ge_3

  for_each = local.switch_port_configs["sw_ge_3"]
    name         = each.key
    description  = each.value.description
    trunk        = length(each.value.vlans) > 1
    vlan_members = each.value.vlans
    ether_opts {
      auto_negotiation    = true
      flow_control        = false
      loopback            = false
      no_auto_negotiation = false
      no_flow_control     = false
      no_loopback         = false
    }
}

# ======== Switch 4 ========

resource junos_interface_physical sw_ge_4_port {

  provider = junos.sw_ge_4

  for_each = local.switch_port_configs["sw_ge_4"]
    name         = each.key
    description  = each.value.description
    trunk        = length(each.value.vlans) > 1
    vlan_members = each.value.vlans
    ether_opts {
      auto_negotiation    = true
      flow_control        = false
      loopback            = false
      no_auto_negotiation = false
      no_flow_control     = false
      no_loopback         = false
    }
}

