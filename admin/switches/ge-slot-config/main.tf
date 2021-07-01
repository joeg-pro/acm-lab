
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


#=== Configuration Info ===

locals {

  # Machine to slot assignment:

  machine_slot_assignments = {
    00 = ["fog_01", "fog_02", "fog_03", "fog_04", "fog_05", "fog_06"],
    02 = ["fog_07", "fog_08", "fog_09", "fog_10", "fog_11", "fog_12"],
    04 = ["fog_13", "fog_14", "fog_15", "fog_16", "fog_17", "fog_18"],
    06 = ["fog_19", "fog_20", "fog_21", "fog_22", "fog_23", "fog_24"]
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

  # Note: Add map entries to local.machine_connections for any new switches.

  machine_connections = {
    sw_ge_1 = local.sw_ge_1_machine_connections
    sw_ge_2 = local.sw_ge_2_machine_connections
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

  # First, use the slot assinment info to produce an augmented machine connection
  # map that adds vlan info into the name, port etc. info in the base map.

  machine_to_slot_nr_map = transpose(local.machine_slot_assignments)
  machine_connections_ext = {
    for sw_n,sw_mc in local.machine_connections: sw_n => {
      for mn,mv in local.machine_connections[sw_n]: mn => {
        name  = mv.name, nics  = mv.nics, ports = mv.ports
        vlans = [
          for i in range(length(mv.ports)):
            mv.nics[i] == 1 ?
              format("test-slot-%02d-prov", tonumber(local.machine_to_slot_nr_map[mn][0])) :
              format("test-slot-%02d-data", tonumber(local.machine_to_slot_nr_map[mn][0]))
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

  # Contributes to the import_info output by import.sh:
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

# Ports (Interfaces):

resource junos_interface_physical sw_ge_1_port {

  provider = junos.sw_ge_1

  for_each = local.switch_port_configs["sw_ge_1"]
    name         = each.key
    description  = each.value.description
    trunk        = length(each.value.vlans) > 1
    vlan_members = each.value.vlans
}

# ======== Switch 2 ========

# Ports (Interfaces):

resource junos_interface_physical sw_ge_2_port {

  provider = junos.sw_ge_2

  for_each = local.switch_port_configs["sw_ge_2"]
    name         = each.key
    description  = each.value.description
    trunk        = length(each.value.vlans) > 1
    vlan_members = each.value.vlans
}


