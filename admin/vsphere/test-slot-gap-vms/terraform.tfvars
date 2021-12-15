
# Note:  Its OK to commit this as it doesn't contain in-line passwords.

# Required:

slot_list             = [02, 06, 08, 10, 12]
# Notes:
# Slots 00,and 04 were in-use prior to this TF having been created
# so for the time being we're leaving them alone.
# 
# Ultimately, slots 00, 02, 04, 06, 08, 10 and 12 are intended for 
# bare metal machines using single-node Fog machines.
# 
# Slos 14 and up are for other purposes.
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
