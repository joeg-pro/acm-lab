
terraform {
  required_version = ">= 0.15.0"
}

#=== "Compile it" Locals ===

# Inputs:
# - local.machine_connections
#
# Outputs:
# - local.switch_port_configs
# - local.import_info

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

  _machine_to_slot_nr_map = transpose(local.machine_slot_assignments)
  _machine_connections_ext = {
    # (Iteration vars: sw_n = switch name, sw_mc = sw_n's machine connections)
    for sw_n,sw_mc in local.machine_connections: sw_n => {
      # (Iteration vars: mn = machine key/id, mv = info about machine mn)
      for mk,mv in local.machine_connections[sw_n]: mk => {
        name  = mv.name, nics  = mv.nics, ports = mv.ports
        vlans = [
          for i in range(length(mv.ports)):
            # Map to slot's provisioning/data VLAN name based on what NIC it is:
            mv.nics[i] == 1 ?
              format("test-slot-%02d-prov", tonumber(local._machine_to_slot_nr_map[mk][0])) :
              format("test-slot-%02d-data", tonumber(local._machine_to_slot_nr_map[mk][0]))
        ]
      }
    }
  }

  # We now need to convert from _machine_connections_ext's map-of-maps where the inner
  # map has one entry per machine into a map-of-maps where the inner map has one entry
  # per port to be configured on that switch.  It seems not possible to do this in one
  # fell swoop because doing that would require the key expression for the inner map to
  #  be insdie a nested for, which TF doesn't seem to like.  So instead we do this
  # in a couple of steps.  (This approach inspired by this GH issue command and related
  # discussion: https://github.com/hashicorp/terraform/issues/22263#issuecomment-581205359)

  # So, convert the _machine_connections_ext into a map from switch-name to a list of
  # port config info to be applied to that switch, using flatten() to flatten out
  # the nesting of the map-value list.

  _spc_intermediate_map_of_lists = {
    for sw_n,sw_mc in local._machine_connections_ext: sw_n => flatten([
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
    for sw_n,sw_pcl in local._spc_intermediate_map_of_lists: sw_n => {
      for e in sw_pcl: e.key =>  e.value
    }
  }

  #----------------------------------------------
  # Collect up import_info for use by import.sh
  #----------------------------------------------

  # Contributes to the import_info output for use by import.sh:
  _switch_port_import_info = flatten([
    for sw_n,sw_pcm in local.switch_port_configs: [
      for pn,pc in sw_pcm: {
        resource = format("junos_interface_physical.%s_port[\"%s\"]", sw_n, pn)
        id = pn
      }
    ]
  ])

  import_info = local._switch_port_import_info
}
