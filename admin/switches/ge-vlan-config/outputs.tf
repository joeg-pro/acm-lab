
# Outputs for use by import.sh in figuring out what to import.

output import_info {
  value = local.import_info
}

# Provide an output with just the switch-port stuff since that is all
# we have to import when added in a new switch.

output new_switch_import_info {
  value = local.switch_port_import_info
}

# output debug_1 {
#   value = local.machine_connections
# }

# output debug_2 {
#   value = local.machine_spc_intermediate
# }
