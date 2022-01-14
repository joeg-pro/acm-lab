
# Note:  Its OK to commit this as it doesn't contain in-line passwords.

# Required:

slot_list             = [00, 02, 03, 04, 06, 08, 10, 12]
# Notes:
#
# Slots 00, 02, 04, 06, 08, 10 and 12 are intended for bare metal machines
# using single-node Fog machines.
# 
# Slots 14 to 19 are reserved for additional bare-metal test slots.
#
# Slots 20 to 48 are for other purposes.
#
# Slot 49 is a special maintenance-mode slot with a configuration that
# brings in a PXE server to install a maintenance RHEL image, etc.

vcenter_user_file     = "/home/jmg/.secrets/vsphere/acm-lab/admin/username.txt"
vcenter_password_file = "/home/jmg/.secrets/vsphere/acm-lab/admin/password.txt"

# Defaulted:

# gap_template_name    = "latest"
# gap_template_pattern = "vm/VM Templates/Base-RHEL-8-GAP"

# vcenter_server   = "10.1.158.10"
# datacenter_name  = "ACM Lab Datacenter"
# cluster_name     = "Workload Cluster"
# datastore_name   = "Mist_Workload_B"
# slot_folder_root = "Test Slot Infrastructure"
