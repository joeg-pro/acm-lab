#!/bin/bash

# Assumes cluster is up and running.
# Assumes ocp login is already done
# Assumes acm-lab/bare-metal/tools is in the PATH.

bmh_names=$(oc -n openshift-machine-api get baremetalhosts -o name)

for bmh_name in $bmh_names; do
   # Eg: baremetlahost.metal3.io/fog07.cluster.internal
   fog_name=${bmh_name#*/}
   fog-power-ctrl $fog_name off
done
