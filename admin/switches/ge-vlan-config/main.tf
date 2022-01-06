
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
  # First (only) switch in rack A35. Acts as "root" switch.

  alias     = "sw_ge_1"
  ip        = "acm-ex2300-1g-1.mgmt.acm.lab.eng.rdu2.redhat.com"
  username  = var.switch_username
  password  = var.switch_password
}

provider junos {
  # First switch in rack A36

  alias     = "sw_ge_2"
  ip        = "acm-ex2300-1g-2.mgmt.acm.lab.eng.rdu2.redhat.com"
  username  = var.switch_username
  password  = var.switch_password
}

provider junos {
  # Second switch in rack A36

  alias     = "sw_ge_3"
  ip        = "acm-ex2300-1g-3.mgmt.acm.lab.eng.rdu2.redhat.com"
  username  = var.switch_username
  password  = var.switch_password
}

provider junos {
  # First (only) switch in rack A37

  alias     = "sw_ge_4"
  ip        = "acm-ex2300-1g-4.mgmt.acm.lab.eng.rdu2.redhat.com"
  username  = var.switch_username
  password  = var.switch_password
}

provider junos {
  # First (only) switch in rack A38

  alias     = "sw_ge_5"
  ip        = "acm-ex2300-1g-5.mgmt.acm.lab.eng.rdu2.redhat.com"
  username  = var.switch_username
  password  = var.switch_password
}


#=== Config Locals ===

locals {

  # Add future switches 4, 5 to this list when future == now.
  sw_ge_numbers = [1, 2, 3, 4, 5]

  #--- VLANs ---

  # Test-slot VLANs

  first_test_slot_nr = 0
  last_test_slot_nr  = 24
  maint_slot_nr      = 49

  slot_list = concat(range(local.first_test_slot_nr, local.last_test_slot_nr+1), [local.maint_slot_nr])

  base_test_slot_vlan_id = 200

  # Patterns for test-slot VLAN names, named after slot:

  data_vlan_name_pattern  = "test-slot-%02d-data"
  data_vlan_descr_pattern = "Test slot %02d data network VLAN"

  prov_vlan_name_pattern  = "test-slot-%02d-prov"
  prov_vlan_descr_pattern = "Test slot %02d provisioning network VLAN"

  # Other non-slot-related 1Gb VLANs:

  other_vlans = {
    rh-network-158 = {
      id = 158,
      description = "Red Hat Lab Netowrk VLAN (10.1.158.0/24)"
    }
    pvt-net-172-18-1 = {
      id = 400
      description = "General-use Cross-Lab Private 1Gb Network VLAN (172.18.1.0/24)"
    }
    not-in-use = {
      id = 499
      description = "VLAN for 1Gb NICs not yet on any other 1Gb network"
    }
  }

  rh_network_vlan_name = "rh-network-158"

  # Set local.exclude_vlans to VLANs you want to delete and then do a TF apply before
  # changing config to actually remove the VLAN.  The first apply will update the
  # port configus to remove use of the VLAN.
  #
  # If not in a VLAN-removal scenario, set local.exclude_vlans to an empty list.

  # exclude_vlans = ["pvt_net_vlan_352"]
  exclude_vlans = []


  #--- Special machine connection to the switches  ---
  # (For machines other than the slot-related Fog machines)

  # VSphere hosts get access to all active (non-excluded) test slot VLANs.
  # (Future: define additional variables for other classes of machines.)
  vlans_for_vsphere_hosts = local.non_excluded_test_slot_vlan_names

  # Libvirt/KVM machines get NIC2 access-mode connections to ??? 1Gb Network
  # Proposal:  Connect them to a general-use private 1Gb network?
  # TEMPORARY: CONNECT TO MAINT PROV NETWORK DURING MACHINE CHECKOUT
  vlans_for_libvirt_hosts = ["test-slot-49-prov"]
  vlans_for_nas_hosts     = ["not-in-use"]

  # VSphere Vapor and Mist hosts are connected into 1Gb Swithc 1 thusly:

  sw_ge_1_non_slot_machines = {
    mist_01  = {
      name="Mist01",    # Name of machine to use in description
      nics=[2],         # The ordinal of the NICs connected (parallel to ports array)
      ports=[0],        # Ordinals of the switch ports to which NICs are connected
      vlans=local.vlans_for_vsphere_hosts  # VLANs to allow
    }
    mist_02  = {name="Mist02",  nics=[2], ports=[1],  vlans=local.vlans_for_vsphere_hosts}
    mist_03  = {name="Mist03",  nics=[2], ports=[2],  vlans=local.vlans_for_vsphere_hosts}
    mist_04  = {name="Mist04",  nics=[2], ports=[3],  vlans=local.vlans_for_vsphere_hosts}
    mist_05  = {name="Mist05",  nics=[2], ports=[4],  vlans=local.vlans_for_vsphere_hosts}
    vapor_01 = {name="Vapor01", nics=[2], ports=[5],  vlans=local.vlans_for_vsphere_hosts}
    vapor_02 = {name="Vapor02", nics=[2], ports=[6],  vlans=local.vlans_for_vsphere_hosts}
    steam_01 = {name="Steam01", nics=[2], ports=[7],  vlans=local.vlans_for_nas_hosts    }
    steam_02 = {name="Steam02", nics=[2], ports=[8],  vlans=local.vlans_for_libvirt_hosts}
    mist_06  = {name="Mist06",  nics=[2], ports=[9],  vlans=local.vlans_for_libvirt_hosts}
    mist_07  = {name="Mist07",  nics=[2], ports=[10], vlans=local.vlans_for_libvirt_hosts}
  }

  sw_ge_2_non_slot_machines = {
    # None. All non-slot machines that used to be connected to this switch
    # are now connected to Sw #1 instead.
  }

  sw_ge_5_non_slot_machines = {
    mist_08  = {name="Mist08",  nics=[2], ports=[18], vlans=local.vlans_for_libvirt_hosts}
    mist_09  = {name="Mist09",  nics=[2], ports=[19], vlans=local.vlans_for_libvirt_hosts}
    mist_10  = {name="Mist10",  nics=[2], ports=[20], vlans=local.vlans_for_libvirt_hosts}
    mist_11  = {name="Mist11",  nics=[2], ports=[21], vlans=local.vlans_for_libvirt_hosts}
    mist_12  = {name="Mist12",  nics=[2], ports=[22], vlans=local.vlans_for_libvirt_hosts}
  }

  # Note: Add map entries to this map for any new switches that have
  # some non-slot-resident machines connected to them.
  machine_connections = {
    sw_ge_1 = local.sw_ge_1_non_slot_machines
    sw_ge_5 = local.sw_ge_5_non_slot_machines
    sw_ge_2 = local.sw_ge_2_non_slot_machines
  }

  #--- Port configs for other special ports ---

  # There are a bunch of unused ports on the switches.

  sw_ge_1_unused_ports = range(11, 46+1)  # Port 47 is for future uplink to RH Network
  sw_ge_2_unused_ports = range(36, 46+1)  # Port 47 is for uplink to RH network
  sw_ge_3_unused_ports = range(12, 47+1)
  sw_ge_4_unused_ports = range(36, 47+1)
  sw_ge_5_unused_ports = range(23, 47+1)

  # Note: Add map entries to this map for any new switches:
  unused_ports = {
    sw_ge_1 = local.sw_ge_1_unused_ports
    sw_ge_2 = local.sw_ge_2_unused_ports
    sw_ge_3 = local.sw_ge_3_unused_ports
    sw_ge_4 = local.sw_ge_4_unused_ports
    sw_ge_5 = local.sw_ge_5_unused_ports
  }

  # Infra-Switch connections:
  #
  # Switch 1: Connected to Switch 2, Switch 4
  #
  # Switch 2: Connected to Switch 1, Switch 3.  Has uplink to RH network.
  # Switch 3: Connected to Switch 2
  #
  # Switch 4: Connected to Switch 1, Switch 5.
  # Switch 5: Connected to Switch 3

  sw_ge_1_special_port_configs = [
    {
      port_name = "ge-0/0/47"
      description = "Future: Uplink to RH network 10.1.158.0 subnet"
      vlans = [local.rh_network_vlan_name]
    },
    {
      port_name = "xe-0/1/2"
      description = "Link to 1Gb switch 1"
      vlans = local.all_vlan_names
    },
    {
      port_name = "xe-0/1/3"
      description = "Link to 1Gb Switch 3"
      vlans = local.all_vlan_names
    },
    {
      port_name = "xe-0/1/0"
      description = "Future ineter-switch link"
      vlans = local.all_vlan_names
    },
    {
      port_name = "xe-0/1/1"
      description = "Future ineter-switch link"
      vlans = local.all_vlan_names
    }
  ]

  sw_ge_2_special_port_configs = [
    {
      port_name = "ge-0/0/47"
      description = "Uplink to RH network 10.1.158.0 subnet"
      vlans = [local.rh_network_vlan_name]
    },
    {
      port_name = "xe-0/1/3"
      description = "Link to 1Gb switch 2"
      vlans = local.all_vlan_names
    },
    {
      port_name = "xe-0/1/2"
      description = "Link to 1Gb switch 5"
      vlans = local.all_vlan_names
    },
    {
      port_name = "xe-0/1/0"
      description = "Future ineter-switch link"
      vlans = local.all_vlan_names
    },
    {
      port_name = "xe-0/1/1"
      description = "Future ineter-switch link"
      vlans = local.all_vlan_names
    }
  ]

  sw_ge_3_special_port_configs = [
    {
      port_name = "xe-0/1/3"
      description = "Link to 1Gb switch 1"
      vlans = local.all_vlan_names
    },
    {
      port_name = "xe-0/1/2"
      description = "Future ineter-switch link"
      vlans = local.all_vlan_names
    },
    {
      port_name = "xe-0/1/0"
      description = "Future ineter-switch link"
      vlans = local.all_vlan_names
    },
    {
      port_name = "xe-0/1/1"
      description = "Future ineter-switch link"
      vlans = local.all_vlan_names
    }
  ]

  sw_ge_4_special_port_configs = [
    {
      port_name = "xe-0/1/2"
      description = "Link to 1Gb switch 5"
      vlans = local.all_vlan_names
    },
    {
      port_name = "xe-0/1/3"
      description = "Link to 1Gb Switch 4"
      vlans = local.all_vlan_names
    },
    {
      port_name = "xe-0/1/0"
      description = "Future ineter-switch link"
      vlans = local.all_vlan_names
    },
    {
      port_name = "xe-0/1/1"
      description = "Future ineter-switch link"
      vlans = local.all_vlan_names
    }
  ]

  sw_ge_5_special_port_configs = [
    {
      port_name = "xe-0/1/3"
      description = "Link to 1Gb switch 3"
      vlans = local.all_vlan_names
    },
    {
      port_name = "xe-0/1/0"
      description = "Future ineter-switch link"
      vlans = local.all_vlan_names
    },
    {
      port_name = "xe-0/1/1"
      description = "Future ineter-switch link"
      vlans = local.all_vlan_names
    },
    {
      port_name = "xe-0/1/2"
      description = "Future ineter-switch link"
      vlans = local.all_vlan_names
    }
  ]

  # Note: Add map entries to this map for any new switches:
  special_ports = {
    sw_ge_1 = local.sw_ge_1_special_port_configs
    sw_ge_2 = local.sw_ge_2_special_port_configs
    sw_ge_3 = local.sw_ge_3_special_port_configs
    sw_ge_4 = local.sw_ge_4_special_port_configs
    sw_ge_5 = local.sw_ge_5_special_port_configs
  }
}

# Resource defintiions are in main-resources.tf to make it easier to omit them
# (eg by renaming the file to *.aside") when debugging all of the "math" done by
# the locals above via outputs.
