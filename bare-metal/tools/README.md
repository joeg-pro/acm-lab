Some tools that can be used to manage Dell servers in the ACM lab using Dell iDRAC interfaces (redfish mostly).

These scripts depend on the following environment variables being set:

- `ACM_LAB_MACHINE_INFO` - Pathname of machine-info yaml file, usually residing in aGit clone of this repo at `bare-meal/acm-lab-machine-info/machine-info.yaml`
- `ACM_LAB_MACHINE_CREDS` - Pathname of a yaml file containing BMC (iDRAC) logon credentials.

Short descriptions of some of the more commonly used tools here:

- `fog-power-ctrl` - Power machines on or off and reboot them
- `fog-boot-once` - Initiate a reboot with a one-time change of boot source (eg. to do a single PXE boot)
- `fog-wipe-first-disk` - Run an iDRAC storage job to wipe-out the contents of the first disk on the machine (by wiping out the disks partition table).  Handy to use in in preparation for doing a clean install.
- `fog-reset-boot-sequence` -Change  the boot -device sequence on a machine back to a standard configuration for lab test machines.
- `show-boot-sequence` Show the current boot-device sequence on a machine.
- `show-jobs` - Show any currently running iDRAC jobs on a machine.
- `get-ocp-cli` - Fetch a copy of the `oc` binary from the OCP mirror site.
- `get-ocp-baremetal-install` Fetch a copy of the`openshift-baremetal-install` installer from the OCP mirror site.
