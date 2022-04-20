#!/bin/bash

# Powers off all of the bare metal notes listed as hosts in install-config.yaml.
#
# Requires:
# - yq/jq
#
# Notes:
#
# - We use the hosts in install-config.yaml to figure out the short fognn name
#   for the host, add then do the power action using the ACM lab for-power-ctrl
#   utility from the acm-lab Git repo (which we assume is cloned, in the PATH, etc.)
#   So this script does NOT use the URL, username or password in install-config.yaml.
#
# - If you've added additional nodes to the cluster via machine sets, this script
#   will not find them/power them off.

# Name of power-ctrl utility.  Assumes in the path.
power_ctrl="fog-power-ctrl"

# Find the hosts mentioned in the OCP install-config.yaml
host_names=$(yq -r ".platform.baremetal.hosts | .[] | .name"  ./install-config.yaml)

# Reduce host names to just the "fognn" first part as that is the way the
# lab machine-info is keyed.  This isn't stricly necessary as most of the lab
# utility scripts will tolerate a trailing domain name, but its consistent with
# what we prefer.

fog_names=""
for hn in $host_names; do
   fog_names="$fog_names ${hn%%.*}"
done

# Power them all off.
$power_ctrl off $fog_names
