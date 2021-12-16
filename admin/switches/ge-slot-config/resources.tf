
terraform {
  required_version = ">= 0.15.0"
}

#=== Resource Definitions ===

# Inputs:
# - Provider names
# - local.switch_port_configs


# Note:  No slot-related connections to Switch 1, hence its not here.

# --- Switch 2 ---

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

# --- Switch 3 ---

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

# --- Switch 4 ---

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

# --- Switch 5 ---

resource junos_interface_physical sw_ge_5_port {

  provider = junos.sw_ge_5

  for_each = local.switch_port_configs["sw_ge_5"]
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
