
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

# There are ACM 10Gb switches in racks A35 and A38.  The switch in
# A35 is referred to as 10g-1, and the one in A38 is 10g-2.

provider junos {
  # 10Gb switch in rack A35.

  alias     = "sw_xe_1"
  ip        = "acm-ex4600-10g-1.mgmt.acm.lab.eng.rdu2.redhat.com"
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

  # The following varaibles define/configure the 10Gb VLANs.

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

  vsphere_only_vlan_names = ["vsphere-admin-vmotion", "vsphere-workload-vmotion"]

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

  cross_lab_vlan_names = ["pvt-net-172-16", "pvt-net-172-17-1", "pvt-net-172-17-2"]

  other_vlans = {
    not-in-use = {
      id = 399
      description = "VLAN for 10Gb NICs not yet on any other 10Gb network"
    }
  }

  all_vlan_defs = merge(local.vsphere_vlans, local.cross_lab_vlans, local.other_vlans)

  # vlans_pending_delete = ["nas-io"]
  vlans_pending_delete = []


  #--- Machine/Switch Connection Topology  ---

  # The following variables define the connection topology between the
  # servers and the switches.

  vlans_for_vsphere = concat(local.cross_lab_vlan_names, local.vsphere_only_vlan_names)
  vlans_for_nas     = local.cross_lab_vlan_names
  vlans_for_libvirt = ["pvt-net-172-17-1"]
  vlans_for_libvirt_xe_1 = ["pvt-net-172-17-1"]
  vlans_for_libvirt_xe_2 = ["not-in-use"]
  vlans_for_fe_hub  = ["pvt-net-172-17-2"]

  vlans_for_nas_xe_1 = ["pvt-net-172-17-2"]
  vlans_for_nas_xe_2 = ["not-in-use"]

  vlans_for_unused_ports = ["not-in-use"]

  sw_xe_1_non_slot_machines = {
    mist_01 = {
      name  = "Mist01"  # Name of machine to use in description
      nics  = [1, 2]    # Ordinals of the NICs connected (parallel to ports array)
      ports = [0, 1]    # Ordinals of the switch ports to which NICs are connected
      vlans = local.vlans_for_vsphere   # VLANs to allow for all connections deifned in this entry
    }
    mist_02  = {name="Mist02",    nics=[1,2], ports=[2,3],   vlans=local.vlans_for_vsphere}
    mist_03  = {name="Mist03",    nics=[1,2], ports=[4,5],   vlans=local.vlans_for_vsphere}
    mist_04  = {name="Mist04",    nics=[1,2], ports=[6,7],   vlans=local.vlans_for_vsphere}
    mist_05  = {name="Mist05",    nics=[1,2], ports=[8,9],   vlans=local.vlans_for_vsphere}

    # NB: Mist-06 and -07 have reversed connections.
    mist_06  = {name="*Mist06*",  nics=[2,1], ports=[18,19], vlans=local.cross_lab_vlan_names}
    mist_07  = {name="*Mist07*",  nics=[2,1], ports=[20,21], vlans=local.cross_lab_vlan_names}

    vapor_01 = {name="Vapor01",   nics=[1,2], ports=[10,11], vlans=local.vlans_for_vsphere}
    vapor_02 = {name="Vapor02",   nics=[1,2], ports=[12,13], vlans=local.vlans_for_vsphere}

    # NB: Steam-02 has reversed connections.
    steam_01_xe_1 = {name="Steam01",   nics=[1], ports=[14], vlans=local.vlans_for_nas_xe_1}
    steam_01_xe_2 = {name="Steam01",   nics=[2], ports=[15], vlans=local.vlans_for_nas_xe_2}
    steam_02_xe_1 = {name="*Steam02*", nics=[1], ports=[17], vlans=local.vlans_for_nas_xe_1}
    steam_02_xe_2 = {name="*Steam02*", nics=[2], ports=[16], vlans=local.vlans_for_nas_xe_2}
  }

  sw_xe_2_non_slot_machines = {

    mist_08_xe_1 =  {name="Mist08",  nics=[1], ports=[0],  vlans=local.vlans_for_libvirt_xe_1}
    mist_08_xe_2 =  {name="Mist08",  nics=[2], ports=[1],  vlans=local.vlans_for_libvirt_xe_2}
    mist_09_xe_1 =  {name="Mist09",  nics=[1], ports=[2],  vlans=local.vlans_for_libvirt_xe_1}
    mist_09_xe_2 =  {name="Mist09",  nics=[2], ports=[3],  vlans=local.vlans_for_libvirt_xe_2}
    mist_10_xe_2 =  {name="Mist10",  nics=[1], ports=[4],  vlans=local.vlans_for_libvirt_xe_1}
    mist_10_xe_1 =  {name="Mist10",  nics=[2], ports=[5],  vlans=local.vlans_for_libvirt_xe_2}
    mist_11_xe_1 =  {name="Mist11",  nics=[1], ports=[6],  vlans=local.vlans_for_libvirt_xe_1}
    mist_11_xe_2 =  {name="Mist11",  nics=[2], ports=[7],  vlans=local.vlans_for_libvirt_xe_2}
    mist_12_xe_1 =  {name="Mist12",  nics=[1], ports=[8],  vlans=local.vlans_for_libvirt_xe_1}
    mist_12_xe_2 =  {name="Mist12",  nics=[2], ports=[9],  vlans=local.vlans_for_libvirt_xe_2}

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
     # Note: Besides standard ports, switch 10g-2 has 2 expansion modules  that
     # provide 8 ports each.  Because they are expansion ports, they are named
     # differently by Junos, and thus are currently not supported/configurable
     # by this Terraform.  None of the expansion ports are currently in use.

  # Note: Add map entries to this map for unused ports of any new switches:
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
