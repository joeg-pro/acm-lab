#!/bin/bash

# From: https://github.com/openshift/installer/blob/master/docs/user/metal/install_ipi.md#network-requirements

if [[ -z "$1" ]]; then
   >&2 echo "A clsuter name is required."
   exit 1
fi

podman run quay.io/openshift/origin-baremetal-runtimecfg:4.5 vr-ids "$1"

