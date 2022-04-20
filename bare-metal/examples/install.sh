#!/bin/bash

# Create an ./ocp directo containing "consumable" copy of install-config.yaml
# and then runs ocp-baremetal-install from within that directory.
#
# The resulting install artifacts (eg. auth subcirectory) will be in ./ocp when done.

# Pre-req:
#
# First run get-ocp-barmetal-install to fetch the appropraite ocp-baremetl-install
# application for the OCP release you wnat to install.  That script puts the installer
# in the ./bin directory where this one expects to find it.

inst_dir="ocp"
rm -rf $inst_dir
mkdir $inst_dir
cp install-config.yaml $inst_dir
cd $inst_dir
../bin/openshift-baremetal-install --log-level debug create cluster

