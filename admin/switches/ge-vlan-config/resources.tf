
# ======== Switch 1 ========

# VLANs:

resource junos_vlan sw_ge_1_vlan {

  provider = junos.sw_ge_1

  for_each = local.all_vlan_defs
    vlan_id     = each.value.id
    name        = replace(each.key, "_", "-")
    description = each.value.description
}

# Ports (Interfaces):

resource junos_interface_physical sw_ge_1_port {

  depends_on = [junos_vlan.sw_ge_1_vlan]

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

# VLANs:

resource junos_vlan sw_ge_2_vlan {

  provider = junos.sw_ge_2

  for_each = local.all_vlan_defs
    vlan_id     = each.value.id
    name        = replace(each.key, "_", "-")
    description = each.value.description
}

# Ports (Interfaces):

resource junos_interface_physical sw_ge_2_port {

  depends_on = [junos_vlan.sw_ge_2_vlan]

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

# VLANs:

resource junos_vlan sw_ge_3_vlan {

  provider = junos.sw_ge_3

  for_each = local.all_vlan_defs
    vlan_id     = each.value.id
    name        = replace(each.key, "_", "-")
    description = each.value.description
}

# Ports (Interfaces):

resource junos_interface_physical sw_ge_3_port {

  depends_on = [junos_vlan.sw_ge_3_vlan]

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

# VLANs:

resource junos_vlan sw_ge_4_vlan {

  provider = junos.sw_ge_4

  for_each = local.all_vlan_defs
    vlan_id     = each.value.id
    name        = replace(each.key, "_", "-")
    description = each.value.description
}

# Ports (Interfaces):

resource junos_interface_physical sw_ge_4_port {

  depends_on = [junos_vlan.sw_ge_4_vlan]

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

# ======== Switch 5 ========

# VLANs:

resource junos_vlan sw_ge_5_vlan {

  provider = junos.sw_ge_5

  for_each = local.all_vlan_defs
    vlan_id     = each.value.id
    name        = replace(each.key, "_", "-")
    description = each.value.description
}

# Ports (Interfaces):

resource junos_interface_physical sw_ge_5_port {

  depends_on = [junos_vlan.sw_ge_5_vlan]

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

