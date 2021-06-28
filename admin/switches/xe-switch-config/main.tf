
# Defines VLANs.
# TODO: Also defines trunk-mode connections and sets them to allow all vlans to flow.

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
  alias     = "sw_xe_1"
  ip        = "acm-ex4600-10g.mgmt.acm.lab.eng.rdu2.redhat.com"
  username  = var.switch_username
  password  = var.switch_password
}


# Rather than get the config from some external file (somehow?) to keep this TF
# a bit simplier we'll deifne the config via local vars.

locals {

  #--- Specify the VLANs we want on each switch ---
  # (This config is applied across all switches.)

  # VLANs accessible only by VSphere cluster nodes.
  vsphere_vlans = {
    vsphere_admin_vmotion = {
      id = 300
      description = "VSphere Admin cluster VMotion network VLAN"
    }

    vsphere_workload_vmotion = {
      id = 301
      description = "VSphere Workload cluster VMotion network VLAN"
    }
  }

  # VLANs accessible by any host in the lab.
  cross_lab_vlans = {
    pvt_net_172_16 = {
      id = 302
      description = "Private network 172.16 VLAN"
    }
    nas_io = {
      id = 303
      description = "iSCSI/NFS I/O network VLAN"
    }

    pvt_net_vlan_350 = {
      id = 350
      description = "Available corss-lab private network VLAN"
    }
    pvt_net_vlan_351 = {
      id = 351
      description = "Available corss-lab private network VLAN"
    }
    # pvt_net_vlan_352 = {
    #   id = 352
    #   description = "Available corss-lab private network VLAN"
    # }
  }

  # This TF config's (or maybe the Junos TF provider in general) depdencny mgmt is not
  # good and leads to problems deleting VLANs since it deletes the VLAN def before
  # modifying all of the ports to remove the use of VLAN.  To get around this, if
  # you want to delete a VLAN, firs tadd it to this exclude list, do a TF apply,
  # and then remove it it from the VLANs map above and from this list and apply again
  # to delete the VLAN def.  Ugly.

  # exclude_vlans = ["pvt_net_vlan_352"]
  exclude_vlans = []

  all_vlan_defs = merge(local.vsphere_vlans, local.cross_lab_vlans)
  all_vlans = {
    for k,v in local.all_vlan_defs: k => {
      id = v.id
      description = v.description
    } if !contains(local.exclude_vlans, k)
  }
  all_vlan_names = [for k,v in local.all_vlans: replace(k, "_", "-")]

  vlans_for_vsphere = local.all_vlan_names

  # Contributes to the import_info output by import.sh:
  vlan_import_info = [
    for k,v in local.all_vlans: {
      resource = format("junos_vlan.sw_xe_1_vlan[\"%s\"]", k)
      id = replace(k, "_", "-")
    }
  ]

  #--- Specify the machine-by-machine connection to the switches  ---

  sw_xe_1_machines = {
    mist_01 = {
      name  = "Mist01"  # Name of machine to use in description
      nics  = [1, 2]    # The ordinal of the NICs connected (parallel to ports array)
      ports = [0, 1]    # Ordinals of the switch ports to which NICs are connected
      vlans = local.vlans_for_vsphere   # VLANs to allow
    }
    mist_02 = {
      name  = "Mist02"
      nics  = [1, 2]
      ports = [2, 3]
      vlans = local.vlans_for_vsphere
    }
    mist_03 = {
      name  = "Mist03"
      nics  = [1, 2]
      ports = [4, 5]
      vlans = local.vlans_for_vsphere
    }
    mist_04 = {
      name  = "Mist04"
      nics  = [1, 2]
      ports = [6, 7]
      vlans = local.vlans_for_vsphere
    }
    mist_05 = {
      name  = "Mist05"
      nics  = [2, 1] # NB: Flipped conneciton order.
      ports = [8, 9]
      vlans = local.vlans_for_vsphere
    }
    vapor_01 = {
      name  = "Vapor01"
      nics  = [1, 2]
      ports = [10, 11]
      vlans = local.vlans_for_vsphere
    }
    vapor_02 = {
      name  = "Vapor02"
      nics  = [1, 2]
      ports = [12, 13]
      vlans = local.vlans_for_vsphere
    }
  }

  # Convert the per-machine connectoin info in local.machines into a map we can for_each over
  # on a swtich port (interface) basis to define the switch port/interface configuration. THe
  # result is local.ports that is a map from siwthc-port (interface) names to desired config
  # values for the port.  We do this via an intermediate list to make it a bit more readable.

  sw_xe_1_machine_port_configs = flatten([
    for mn,mv in local.sw_xe_1_machines: [
      for i in range(length(mv.ports)) : {
        port_name = format("xe-0/0/%s", mv.ports[i])
        description = format("%s 10G NIC %d", mv.name, mv.nics[i])
        vlans = mv.vlans
      }
    ]
  ])

  # Future: Interconnection between switches.
  # One of ports 24 through 27.  40G.  Designated as eg. et-0/0/24.
  # Each splits out to 4 10G ports designated as xe-0/0/24:0 to /24:3.

  # Note: As additional sub-lists are created, concat into this one.
  sw_xe_1_port_configs = local.sw_xe_1_machine_port_configs

   # For_each needs a map (or set), so make a map.
  sw_xe_1_ports = {
    for e in local.sw_xe_1_port_configs: e.port_name => {
       description = e.description
       vlans = e.vlans
    }
  }

  # Contributes to the import_info output by import.sh:
  sw_xe_1_import_info = [
    for e in local.sw_xe_1_port_configs: {
      resource = format("junos_interface_physical.sw_xe_1_port[\"%s\"]", e.port_name)
      id = e.port_name
    }
  ]

  # Combine all import info into a single thing referenced as an ooutput.

  import_info = concat(local.vlan_import_info, local.sw_xe_1_import_info)

}

# ======== 10G Switch 1 ========

# VLANs:

resource junos_vlan sw_xe_1_vlan {

  provider = junos.sw_xe_1

  for_each = local.all_vlan_defs
    vlan_id     = each.value.id
    name        = replace(each.key, "_", "-")
    description = each.value.description
}

# Ports (Interfaces):

resource junos_interface_physical sw_xe_1_port {

  depends_on = [junos_vlan.sw_xe_1_vlan]

  provider = junos.sw_xe_1

  for_each = local.sw_xe_1_ports
    name         = each.key
    description  = each.value.description
    trunk        = length(each.value.vlans) > 1
    vlan_members = each.value.vlans
}

