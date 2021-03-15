#!/bin/bash

# Informal.
# Cleans up/destroys a bare metal cluster.

# Assume its in the path.
power_ctrl="fog-power-ctrl"

# Find the GAP VM being used
gap_uri=$(yq -r ".platform.baremetal.libvirtURI"  ./install-config.yaml)
user_at_host=${gap_uri#*//}
user_at_host=${user_at_host%%/*}

echo "Cleaning up any bootstrap VM remnants."
ssh $user_at_host sudo bare-metal/cleanup-bootstrap.sh

# Find the hosts mentioned in the OCP install-config.yaml
host_names=$(yq -r ".platform.baremetal.hosts | .[] | .name"  ./install-config.yaml)

for fog in $host_names; do 
   echo "Powering $fog off."
   $power_ctrl $fog off
done

rm -rf ocp

