
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
  # Note: Switch 1 has no slot-resident machines connected to it, so there is no
  # further config for it in this TF.  But the provider is defined keep it handy.

  alias     = "sw_ge_1"
  ip        = "acm-ex2300-1g-1.mgmt.acm.lab.eng.rdu2.redhat.com"
  username  = var.switch_username
  password  = var.switch_password
}

provider junos {
  # First switch in rack A36.
  # (This rack holds Fog01 to Fog24.)

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
  # (This rack holds Fog25 to Fog42.)

  alias     = "sw_ge_4"
  ip        = "acm-ex2300-1g-4.mgmt.acm.lab.eng.rdu2.redhat.com"
  username  = var.switch_username
  password  = var.switch_password
}

provider junos {
  # First (only) switch in rack A38
  # (This rack holds Fog43 to Fog51.)

  alias     = "sw_ge_5"
  ip        = "acm-ex2300-1g-5.mgmt.acm.lab.eng.rdu2.redhat.com"
  username  = var.switch_username
  password  = var.switch_password
}


#=== Configuration Info ===

# The local vars in this section define the configuration of machines to slots in a compact
# way.  These local vars are then "muncged" by (used as input to and transforemd by) some
# "compile-it" stuff to turn this into something we use to configure a set of TF resources.
# In a sense, these locals represent a DSL for definining slot/machine configuration.)

locals {

  # Machine to slot assignment is expressed in the machine_slot_assignment map, by
  # specifying for each slot the list of machines that live in that slot.

  # Note: Every "Fog" machine under this TF's perview needs to be assigned to some slot.
  # Slot 49 is the maintenance slot so assign a machine to that slot if currently unused
  # (or "in the garage" for repairs or refurbishment).

  machine_slot_assignments = {
    00 = ["fog_01", "fog_02", "fog_03", "fog_04", "fog_05", "fog_06"],
    02 = ["fog_07", "fog_08", "fog_09"],
    03 = ["fog_10", "fog_11", "fog_12"],
    04 = ["fog_13", "fog_14", "fog_15", "fog_16", "fog_17", "fog_18"],
    06 = ["fog_19", "fog_20", "fog_21", "fog_22", "fog_23", "fog_24"],
    08 = ["fog_25", "fog_26", "fog_27", "fog_28", "fog_29", "fog_30"],
    10 = ["fog_31", "fog_32", "fog_33", "fog_34", "fog_35", "fog_36"],
    12 = ["fog_37", "fog_38", "fog_39", "fog_40", "fog_41", "fog_42"],
    49 = ["fog_43", "fog_44", "fog_45", "fog_46", "fog_47", "fog_48",
          "fog_49", "fog_50", "fog_51"]
  }

  # Machine NIC to switch port configuration:

  sw_ge_2_machine_connections = {
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

  sw_ge_3_machine_connections = {
    fog_19 = {name="Fog19", nics=[1, 2], ports=[0, 1]},
    fog_20 = {name="Fog20", nics=[1, 2], ports=[2, 3]},
    fog_21 = {name="Fog21", nics=[1, 2], ports=[4, 5]},
    fog_22 = {name="Fog22", nics=[1, 2], ports=[6, 7]},
    fog_23 = {name="Fog23", nics=[1, 2], ports=[8, 9]},
    fog_24 = {name="Fog24", nics=[1, 2], ports=[10, 11]}
  }

  sw_ge_4_machine_connections = {
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

  sw_ge_5_machine_connections = {
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
    sw_ge_2 = local.sw_ge_2_machine_connections
    sw_ge_3 = local.sw_ge_3_machine_connections
    sw_ge_4 = local.sw_ge_4_machine_connections
    sw_ge_5 = local.sw_ge_5_machine_connections
  }

}

# Local variables to "compile" above config into a form that can be used by
# resource for-each iteration is in compile-it.tf.

# Resource defintiions are in resources.tf to make it easier to omit them
# (eg by renaming the file to *.aside") when debugging all of the "math" done
# by the locals above via outputs.
