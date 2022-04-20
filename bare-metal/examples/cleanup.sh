#!/bin/bash

# Informal/WIP.
#
# Cleans up/destroys a bare metal cluster:
#
# - Gets rid of any remnants of the Bootstrap VM on the GAP VM for the slot.
# - Powers off all of the hosts in the cluster (as specifed in install-config.yaml)
# - Deletes ./ocp directory.
#
# Requires:
# - yq/jq

me=$(basename $0)
my_dir=$(dirname $(readlink -f $0))

power_off="$my_dir/power-off-nodes.sh"

# Find the GAP VM being used
gap_uri=$(yq -r ".platform.baremetal.libvirtURI"  ./install-config.yaml)
user_at_host=${gap_uri#*//}
user_at_host=${user_at_host%%/*}

# SSH into the GAP and run the cleanup script we have there as part
# of the standard GAP VM image.
echo "Cleaning up any bootstrap VM remnants."
ssh $user_at_host sudo bare-metal/cleanup-bootstrap.sh

# Power off all the machines.
$power_off

rm -rf ocp

