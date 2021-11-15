
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
}
