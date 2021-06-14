#!/bin/bash

# We need TF >= 0.14 at this alias.
tf="terraform-14"

# Range of test-slot VLANs:

first_vlan_id=200
last_vlan_id=249

for id in $(seq $first_vlan_id $last_vlan_id); do
   $tf import "junos_vlan.sw1_test_slot_vlan[\"$id\"]" test-slot-vlan-$id
   $tf import "junos_vlan.sw2_test_slot_vlan[\"$id\"]" test-slot-vlan-$id
done

# Other VLANs:

$tf import junos_vlan.sw1_rh_network_vlan "rh-network-158"
$tf import junos_vlan.sw2_rh_network_vlan "rh-network-158"

# Switch 1 and 2 ports 36-47 connections:

for id in $(seq 36 47); do
   $tf import junos_interface_physical.sw1_port_$id "ge-0/0/$id"
   $tf import junos_interface_physical.sw2_port_$id "ge-0/0/$id"
done

# Swtich 1 connections to other switches:

$tf import junos_interface_physical.sw1_10g_port_3 "xe-0/1/3"

# Swtich 2 connections to other switches:

$tf import junos_interface_physical.sw2_10g_port_3 "xe-0/1/3"

