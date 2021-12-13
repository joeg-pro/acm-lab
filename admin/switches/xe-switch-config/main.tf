
# Defines VLAN, non-slot port connections and inter-switch trunk connections.
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
  # 10Gb switch in rack A35.

  alias     = "sw_xe_1"
  ip        = "acm-ex4600-10g.mgmt.acm.lab.eng.rdu2.redhat.com"
  username  = var.switch_username
  password  = var.switch_password
}

provider junos {
  # 10Gb switch in rack A38.

  alias     = "sw_xe_2"
  ip        = "acm-ex4600-10g-2.mgmt.acm.lab.eng.rdu2.redhat.com"
  username  = var.switch_username
  password  = var.switch_password
}

#=== Config Locals ===

locals {

  # Add to this list as new switches are added.
  sw_names = ["sw_xe_1", "sw_xe_2"]

  port_type  = "xe"
  port_speed = 10

  #--- VLANs ---
  # VLANs accessible only by VSphere cluster nodes.
  vsphere_vlans = {
    vsphere-admin-vmotion = {
      id = 300
      description = "VSphere Admin cluster VMotion network VLAN"
    }

    vsphere-workload-vmotion = {
      id = 301
      description = "VSphere Workload cluster VMotion network VLAN"
    }
  }

  # VLANs accessible by any host in the lab.
  cross_lab_vlans = {
    pvt-net-172-16 = {
      id = 302
      description = "Deprecated Private network 172.16 VLAN"
    }
    pvt-net-172-17-1 = {
      id = 303
      description = "General-use Cross-Lab Private 10Gb Network VLAN (172.17.1.0/24)"
    }
    pvt-net-172-17-2 = {
      id = 304
      description = "iSCSI/NFS I/O network VLAN (172.17.2.0/24)"
    }
  }

  all_vlan_defs = merge(local.vsphere_vlans, local.cross_lab_vlans)

  # vlans_pending_delete = ["nas-io"]
  vlans_pending_delete = []

  #--- Special machine connection to the switches  ---
  # (For machines other than the slot-related Fog machines)

  vlans_for_vsphere  = local.all_vlan_names
  vlans_for_libvirt  = ["pvt-net-172-17-1"]
  vlans_for_fe_hub   = ["pvt-net-172-17-2"]

  vlans_for_unused_ports = ["pvt-net-172-17-1"]

  sw_xe_1_non_slot_machines = {
    mist_01 = {
      name  = "Mist01"  # Name of machine to use in description
      nics  = [1, 2]    # The ordinal of the NICs connected (parallel to ports array)
      ports = [0, 1]    # Ordinals of the switch ports to which NICs are connected
      vlans = local.vlans_for_vsphere   # VLANs to allow
    }
    mist_02  = {name="Mist02",  nics=[1,2], ports=[2,3],   vlans=local.vlans_for_vsphere}
    mist_03  = {name="Mist03",  nics=[1,2], ports=[4,5],   vlans=local.vlans_for_vsphere}
    mist_04  = {name="Mist04",  nics=[1,2], ports=[6,7],   vlans=local.vlans_for_vsphere}

    # NB: Mist 05 has flipped connection order.
    mist_05  = {name="*Mist05*",  nics=[2,1], ports=[8,9],   vlans=local.vlans_for_vsphere}
    vapor_01 = {name="Vapor01", nics=[1,2], ports=[10,11], vlans=local.vlans_for_vsphere}
    vapor_02 = {name="Vapor02", nics=[1,2], ports=[12,13], vlans=local.vlans_for_vsphere}
    steam_01 = {name="*Steam01*", nics=[2,1], ports=[14,15], vlans=local.vlans_for_libvirt}
    steam_02 = {name="*Steam02*", nics=[2,1], ports=[16,17], vlans=local.vlans_for_libvirt}
    mist_06  = {name="*Mist06*",  nics=[2,1], ports=[18,19], vlans=local.vlans_for_libvirt}
    mist_07  = {name="*Mist07*",  nics=[2,1], ports=[20,21], vlans=local.vlans_for_libvirt}
  }

  sw_xe_2_non_slot_machines = {
    mist_08 =  {name="Mist08",  nics=[1,2], ports=[0,1],   vlans=local.vlans_for_libvirt}
    mist_09 =  {name="Mist09",  nics=[1,2], ports=[2,3],   vlans=local.vlans_for_libvirt}
    mist_10 =  {name="Mist10",  nics=[1,2], ports=[4,5],   vlans=local.vlans_for_libvirt}
    mist_11 =  {name="Mist11",  nics=[1,2], ports=[6,7],   vlans=local.vlans_for_libvirt}
    mist_12 =  {name="Mist12",  nics=[1,2], ports=[8,9],   vlans=local.vlans_for_libvirt}
    fog_43  =  {name="Fog43",   nics=[1],   ports=[10],    vlans=local.vlans_for_fe_hub}
    fog_44  =  {name="Fog44",   nics=[1],   ports=[11],    vlans=local.vlans_for_fe_hub}
    fog_45  =  {name="Fog45",   nics=[1],   ports=[12],    vlans=local.vlans_for_fe_hub}
    fog_46  =  {name="Fog46",   nics=[1],   ports=[13],    vlans=local.vlans_for_fe_hub}
    fog_47  =  {name="Fog47",   nics=[1],   ports=[14],    vlans=local.vlans_for_fe_hub}
    fog_48  =  {name="Fog48",   nics=[1],   ports=[15],    vlans=local.vlans_for_fe_hub}
    fog_49  =  {name="Fog49",   nics=[1],   ports=[16],    vlans=local.vlans_for_fe_hub}
    fog_50  =  {name="Fog50",   nics=[1],   ports=[17],    vlans=local.vlans_for_fe_hub}
    fog_51  =  {name="Fog51",   nics=[1],   ports=[18],    vlans=local.vlans_for_fe_hub}
  }

  # Note: Add map entries to this map for any new switches that have
  # some non-slot-resident machines connected to them.
  machine_connections = {
    sw_xe_1 = local.sw_xe_1_non_slot_machines
    sw_xe_2 = local.sw_xe_2_non_slot_machines
  }

  #--- Port configs for other special ports ---

  # There are a bunch of unused ports on the switches.

  sw_xe_1_unused_ports = range(22, 23+1)
  sw_xe_2_unused_ports = range(22, 23+1)
     # PLUS EXPANSION PORTS, NAMED DIFFERENTLY.

  # Note: Add map entries to this map for any new switches:
  unused_ports = {
    sw_xe_1 = local.sw_xe_1_unused_ports
    sw_xe_2 = local.sw_xe_2_unused_ports
  }

  # Infra-Switch connections:

  sw_xe_1_special_port_configs = [
    {
      port_name = "et-0/0/24"
      description = "Link to 10Gb switch 2"
      vlans = local.all_vlan_names
    },
    {
      port_name = "et-0/0/25"
      description = "Future ineter-switch link"
      vlans = local.all_vlan_names
    },
    {
      port_name = "et-0/0/26"
      description = "Future ineter-switch link"
      vlans = local.all_vlan_names
    },
    {
      port_name = "et-0/0/27"
      description = "Future ineter-switch link"
      vlans = local.all_vlan_names
    }
  ]

  sw_xe_2_special_port_configs = [
    {
      port_name = "et-0/0/24"
      description = "Link to 10Gb switch 1"
      vlans = local.all_vlan_names
    },
    {
      port_name = "et-0/0/25"
      description = "Future ineter-switch link"
      vlans = local.all_vlan_names
    },
    {
      port_name = "et-0/0/26"
      description = "Future ineter-switch link"
      vlans = local.all_vlan_names
    },
    {
      port_name = "et-0/0/27"
      description = "Future ineter-switch link"
      vlans = local.all_vlan_names
    }
  ]

  # Note: Add map entries to this map for any new switches:
  special_ports = {
    sw_xe_1 = local.sw_xe_1_special_port_configs
    sw_xe_2 = local.sw_xe_2_special_port_configs
  }
}

# Local variables to "compile" above config into a form that can be used
# by resource for-each iteration is in compile-it.tf.

# Resource defintiions are in main-resources.tf to make it easier to omit them
# (eg by renaming the file to *.aside") when debugging all of the "math" done by
# the locals above via outputs.
