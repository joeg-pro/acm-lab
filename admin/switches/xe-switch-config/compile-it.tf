
# Goal (not yet achieved): Share this TF with the 1GB Switch TF too
# as the logic is nearly identical.

terraform {
  required_version = ">= 0.15.0"
}

#=== Compile-It Locals/Logic for defining VLANs ===

locals {

  # Logic/variables for dealing with TF dependency issues when deleting VLAN.

  # This TF config's (or maybe the Junos TF provider's in general) depdencny mgmt re VLANs
  # is not good and leads to problems deleting VLANs since TF tries to delete the VLAN def
  # before modifying all of the ports to remove the use of VLAN. The exclude_vlans
  # variable and code that follows is our current workaround for this.
  #
  # If you want to delete VLANs, sSet local.exclude_vlans to the list of VLANs you want to
  # delete and then do a TF apply before changing config to actually remove the VLAN.
  # The first apply will update the port configus to remove use of the VLAN.
  #
  # If not in a VLAN-removal scenario, set local.exclude_vlans to an empty list.
  #
  # Note: Currently the following code only adjusts/filters the all_vlan_names local
  # variable, but not any others that might also have lists of VLANs in it.  This has
  # been good enough because the main problems occur in the definition of the trunk mode
  # ports which list every VLAN.  But it might occur in other cases too (and isn't yet
  # handled) if ports get lists of VLANs.

  # Required input vlans_pending_delete = []
  exclude_vlans = local.vlans_pending_delete

  # Local.all_vlan_defs holds definition info ror all VLANs, including the ones we are
  # trying to delete. Local.all_vlans is the subset of all_vlan_defs that excludes the
  # onces we are trying to delete and is the variable that should be the source of
  # VLAN defs for ports.

  all_vlans = {
    for k,v in local.all_vlan_defs: k => {
      id = v.id
      description = v.description
    } if !contains(local.exclude_vlans, k)
  }
  all_vlan_names = [for k,v in local.all_vlans: replace(k, "_", "-")]

  vlan_import_info_nested = [
    for sw_n in local.sw_names: [
      for v in local.all_vlan_names: {
        resource = format("junos_vlan.%s_vlan[\"%s\"]", sw_n, v)
        id = replace(v, "_", "-")
      }
    ]
  ]

  #----------------------------
  # Compute VLAN import info.
  #----------------------------

  vlan_import_info = flatten(local.vlan_import_info_nested)

}

#=== Compile-It Locals/Logic for port connections ===

locals {

  #------------------------------------------------------------------
  # "Compile" machine-connection/switch port info into usable form.
  #------------------------------------------------------------------

  # The configuration local variables in the section Config Locals above define the physcial
  # connections in various waus chosen to result in an easy/compact way of spec'ing these.
  #
  # But in order to actually define port configs via TF for_each iteratoin, those compact
  # defintiions need to be "compiled" -- converted and aggregated -- into a map of maps
  # where the outer map has one entry per switch, and the inner map for that switch has
  # one entry per port to be configured.  That's what the following hunks of logic does,
  # with slight vartions needed for each of the input local vars.

  # It seems not possible to do this kind of compiling in one fell swoop because sometimes
  # the nesting means the fell swoop would require the key expression for the inner map to
  # be insdie a nested for, which TF doesn't seem to allow, at least not syntatically.
  # And trying a big fell swoop would probably make this impossible to debug (not that it
  # isn't challenging already).
  #
  # So instead we convert the various inputs into a common intermediate form, which is
  # ten easily converted into a map of maps. This approach is inspired by the following
  # G issue command and related discussion:
  # https://github.com/hashicorp/terraform/issues/22263#issuecomment-581205359)


  # Convert special machine (eg. mists/vapors) connections to intermediate form.

  # This converts local.machine_connections, which looks like this:
  #
  # macine_connections = {
  #   sw_ge_1 = {
  #     mist_01  = {
  #       name  = "Mist01"
  #       nics  = [2]
  #       ports = [40]
  #       vlans = [
  #         "test-slot-00-data",
  #         "test-slot-00-prov",
  #         "test-slot-01-data",
  #         "test-slot-01-prov",
  #         ...
  #         "test-slot-49-data",
  #         "test-slot-49-prov",
  #       ]
  #     },
  #     mist_02  = {
  #       name  = "Mist02"
  #       nics  = [2]
  #       ports = [41]
  #       vlans = [
  #         "test-slot-00-data",
  #         "test-slot-00-prov",
  #         "test-slot-01-data",
  #         "test-slot-01-prov",
  #         ...
  #         "test-slot-49-data",
  #         "test-slot-49-prov",
  #       ]
  #     },
  #   },
  #   sw_ge_2 = {
  #     ...
  #   }
  # }
  #
  # Into something that looks like this:
  #
  # machine_spc_intermediate = {
  #   sw_ge_1 = [
  #     {
  #       key   = "ge-0/0/40"
  #       value = {
  #         description = "Mist01 1G NIC 2"
  #         vlans = [
  #           "test-slot-00-data",
  #           "test-slot-00-prov",
  #           "test-slot-01-data",
  #           "test-slot-01-prov",
  #           ...
  #         ]
  #       }
  #     },
  #     {
  #       key   = "ge-0/0/41"
  #       value = {
  #         description = "Mist02 1G NIC 2"
  #         vlans = [
  #           "test-slot-00-data",
  #           "test-slot-00-prov",
  #           "test-slot-01-data",
  #           "test-slot-01-prov",
  #           ...
  #         ]
  #       }
  #     },
  #     ...
  #   ],
  #   sw_ge_2 = [
  #     ...
  #   ]
  # }

  machine_spc_intermediate = {
    for sw_n,sw_mc in local.machine_connections: sw_n => flatten([
      for mn,mv in sw_mc: [
        for i in range(length(mv.ports)): {
          key = format("%s-0/0/%s", local.port_type, mv.ports[i])
          value = {
            description = format("%s %dG NIC %d", mv.name, local.port_speed, mv.nics[i])
            vlans = sw_mc[mn].vlans
            # Note: Currently, all ports for a machine have the same VLANs.
          }
        }
      ]
    ])
  }

  # Convert unused port defintiions to intermediate form.

  unused_spc_intermediate = {
    for sw_n,sw_upl in local.unused_ports: sw_n => flatten([
      for upn in sw_upl: [{
        key = format("%s-0/0/%s", local.port_type, upn)
        value = {
          description = ""
          vlans = local.vlans_for_unused_ports
        }
      }]
    ])
  }

  # Convert special port configs into intermediate form.

  special_spc_intermediate = {
    for sw_n,sw_pcl in local.special_ports: sw_n => flatten([
      for pci in sw_pcl: [{
        key = pci.port_name
        value = {
          description = pci.description
          vlans = pci.vlans
        }
      }]
    ])
  }


  # Combine the above intermediate forms and convert the result into  the map of maps
  # we'll use to for-each in the per-switch junos.physcial_interface resources.

  spc_intermediate = {
    for sw_n in local.sw_names: sw_n => concat(
      lookup(local.machine_spc_intermediate, sw_n, []),
      lookup(local.unused_spc_intermediate, sw_n, []),
      lookup(local.special_spc_intermediate, sw_n, [])
    )
  }

  switch_port_configs = {
    for sw_n,sw_pcl in local.spc_intermediate: sw_n => {
      for e in sw_pcl: e.key =>  e.value
    }
  }

  #----------------------------------------------
  # Compute port-config import info.
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

  #----------------------------------------------------------------------------
  # Combine all import-info parts into a single thing referenced as an output.
  #----------------------------------------------------------------------------

  import_info = concat(local.vlan_import_info, local.switch_port_import_info)

}

