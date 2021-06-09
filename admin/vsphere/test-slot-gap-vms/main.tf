
terraform {
  required_version = ">= 0.14.0"
  required_providers {
    vsphere = {
      version = "~> 2.0.0"
    }
  }
}

locals {
   # Use slot-vlist variable, unless you want to get fancy.
   # (Alas, you can't use functions in terraform.tfvars.)

   slot_list = var.slot_list
   # slot_list = concat([0, 1, 3], range(5, 20))
}

provider vsphere {
  user                 = local.vcenter_username
  password             = local.vcenter_password
  vsphere_server       = var.vcenter_server
  allow_unverified_ssl = true
}

data vsphere_datacenter dc {
  name = var.datacenter_name
}

data vsphere_compute_cluster compute_cluster {
  name          = var.cluster_name
  datacenter_id = data.vsphere_datacenter.dc.id
}

data vsphere_datastore datastore {
  name          = var.datastore_name
  datacenter_id = data.vsphere_datacenter.dc.id
}

locals {

  slot_set  = toset(formatlist("%02d", local.slot_list))

  # Yeilds eg: Test Slot Infrastructure/Slot-10 when formatted with slot number.

  folder_path_pfx     = var.slot_folder_root != "" ? "${var.slot_folder_root}/" : ""
  folder_path_pattern = "${local.folder_path_pfx}Slot-%02d"

  # Yields eg. Test-Slot-10-GAP when formatted with slot number.
  vm_name_pattern     = "Test-Slot-%02d-GAP"

  resource_pool_id  = data.vsphere_compute_cluster.compute_cluster.resource_pool_id

  # Use template name specified as a variable, unless it was specified as "latest"
  # in whcih case we use a helper script to figure out the latest template version.

  get_latest_version = var.gap_template_name == "latest" ? 1 : 0
  gap_template_name  = local.get_latest_version == 1 ? local.latest_template_name : var.gap_template_name

  latest_template_name = data.external.latest_template.result.template_name
}

# Terraform's VSphere provider doesn't have a built in data source for picking a template
# based on the latest one following a version-date-stamped naming pattern.  So this external
# data source does just that for us.

data external latest_template {
  program = ["bash", "${path.root}/data-sources/latest-template.sh"]

  query = {
    vcenter_server     = var.vcenter_server
    vcenter_username   = local.vcenter_username
    vcenter_password   = local.vcenter_password
    vsphere_datacenter = var.datacenter_name
    vsphere_datastore  = var.datastore_name
    template_pattern   = var.gap_template_pattern
  }
}

module gap_vm {
  source        = "./modules/slot-gateway"

  for_each = local.slot_set

  vm_name           = format(local.vm_name_pattern, each.key)
  folder_path       = format(local.folder_path_pattern, each.key)

  slot_nr           = each.key

  ext_network_name  = "Red Hat Network"
  data_network_name = format("Test Slot %02d Data Network", each.key)
  prov_network_name = format("Test Slot %02d Provisioning Network", each.key)

  template_name     = local.gap_template_name

  datacenter_id     = data.vsphere_datacenter.dc.id
  resource_pool_id  = local.resource_pool_id
  datastore_id      = data.vsphere_datastore.datastore.id
}
