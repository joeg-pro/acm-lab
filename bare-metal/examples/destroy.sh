#!/bin/bash

# Informal/WIP.
#
# Destroys a bare metal cluster, including wiping the first disk of
# each machine to prevent it from being re-started into the latent OS.
#
# Requires:
# - yq/jq

me=$(basename $0)
my_dir=$(dirname $(readlink -f $0))

cleanup="$my_dir/cleanup.sh"
wipe="fog-wipe-first-disk"  # Assume its found in PATH.

# Run cleanup.sh, which cleans up remnants on the GAP and powers
# off all of the nodes.

$cleanup

# Find the hosts mentioned in the OCP install-config.yaml
host_names=$(yq -r ".platform.baremetal.hosts | .[] | .name"  ./install-config.yaml)

# Reduce host names to just the "fognn" first part.
fog_names=""
for hn in $host_names; do
   fog_names="$fog_names ${hn%%.*}"
done

# Wipe first disks on all.
$wipe $fog_names

