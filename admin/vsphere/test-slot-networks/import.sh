#!/bin/bash

# Use this to import existing test-slot networks if you don't have
# a currrent tfstate available.


tf="terraform-new"

# The Terraform VSphere provider talks about importing using a managed-object
# id like in the following example
#
#   terraform import vsphere_distributed_port_group.pg dvportgroup-67
#
# And mentions using eg. govc nventory funcitons to get these.  Our first attempt
# used a data source to do a query to get such an id for en existing network,
# but when importing via it the Vsphere provider compalined that a Data Center
# id was requred.
#
# But reports re importing showed a different format using an object-name path
# (or whatveer the right VSphere term for htis is) and that works, so that's
# what we're now doing with the 2.0.0 version of the VSphere provier.

function import_slot {
   slot_nr=$(printf "%02d" "$1")

   echo "Importing networks for Test Slot $slot_nr"

   for nw in Data Provisioning; do
      nw_name="Test Slot $slot_nr $nw Network"

      # $tf refresh -var="import_network_name=$nw_name" > /dev/null
      # if [[ $? -ne 0 ]]; then
      #    >&2 echo "Can't get the id of network $nw_name."
      #    return 4
      # fi
      # net_id=$($tf output -raw import_network_id)

      resource_name="module.slot[\"$slot_nr\"].vsphere_distributed_port_group"

      if [[ $nw == "Data" ]]; then
         resource_name+=".data_network"
      else
         resource_name+=".prov_network"
      fi

      # $tf import $resource_name "/ACM Lab Datacenter/$net_id"
      $tf import $resource_name "/ACM Lab Datacenter/network/$nw_name"

   done
}

# Test slots 2 and 3 are legacy and don't yet coorespond to currnet naming
# so we'll skip them for now.

for sn in 0 1 3 $(seq -s' ' 5 10); do
   import_slot $sn
done

