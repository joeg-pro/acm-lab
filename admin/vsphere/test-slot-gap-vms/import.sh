#!/bin/bash

# Use this to import existing test-slot GAP VMs if you don't have
# a currrent tfstate available.

tf="terraform-15"

function import_slot_gap_vm {
   slot_nr=$(printf "%02d" "$1")

   echo "Importing GAP VM for Test Slot $slot_nr"

   folder_name="Slot-$slot_nr"
   gap_vm_name="Test-Slot-$slot_nr-GAP"

   vsphere_obj_id="/ACM Lab Datacenter/vm/Test Slot Infrastructure/$folder_name/$gap_vm_name"
   resource_name="module.gap_vm[\"$slot_nr\"].vsphere_virtual_machine.vm"

   $tf import "$resource_name" "$vsphere_obj_id"
}

# Test slots 2 and 3 are legacy and don't yet coorespond to currnet naming
# so we'll skip them for now.

slots="0 1 3 $(seq -s' ' 5 10)"
slots="12"

for sn in $slots; do
   import_slot_gap_vm $sn
done

