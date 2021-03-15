#!/bin/bash

# Run get-ocp-baremetal-install.  It puts installer into bin directory.
# This script then creates an ocp directory to hold install-state,
# copies install-config.yaml into and does an install using the
# openshift-baremetal-install found in ./bin.

inst_dir="ocp"
rm -rf $inst_dir
mkdir $inst_dir
cp install-config.yaml $inst_dir
cd $inst_dir
../bin/openshift-baremetal-install --log-level debug create cluster

