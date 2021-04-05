
terraform {
  required_version = ">= 0.14.0"
}

terraform {
  required_providers {
    junos = {
      source = "jeremmfr/junos"
    }
  }
}

variable switch_username {
  description = "Username to use to authenticate to the switches."
  type = string
}

variable switch_password {
  description = "Password to use to authenticate to the switches."
  type = string
}

provider junos {
  #alias     = "sw1"
  ip        = "acm-2300-1g.mgmt.acm.lab.eng.rdu2.redhat.com"
  username  = var.switch_username
  password  = var.switch_password
}

provider junos {
  alias     = "sw2"
  ip        = "acm-2300-1g-2.mgmt.acm.lab.eng.rdu2.redhat.com"
  username  = var.switch_username
  password  = var.switch_password
}

module slot_00 {
  # Gdaniec
  source = "./modules/slot-config"
  data_vlan         = 200
  provisioning_vlan = 201
}

module slot_01 {
  # Gdaniec
  source = "./modules/slot-config"
  data_vlan         = 202
  provisioning_vlan = 203
}

module slot_02 {
  # QE
  source = "./modules/slot-config"
  data_vlan         = 204
  provisioning_vlan = 205
}

module slot_03 {
  # QE - Hold for future split of slot 02
  source = "./modules/slot-config"
  data_vlan         = 206
  provisioning_vlan = 207
}

module slot_04 {
  # QE
  source = "./modules/slot-config"
  data_vlan         = 208
  provisioning_vlan = 209
}

module slot_05 {
   # QE - Hold for suture split of slot 04
  source = "./modules/slot-config"
  data_vlan         = 210
  provisioning_vlan = 211
}

module slot_06 {
  source = "./modules/slot-config"
  data_vlan         = 212
  provisioning_vlan = 213
}

module slot_07 {
  source = "./modules/slot-config"
  data_vlan         = 214
  provisioning_vlan = 215
}

module slot_08 {
  source = "./modules/slot-config"
  data_vlan         = 216
  provisioning_vlan = 217
}

module slot_09 {
  source = "./modules/slot-config"
  data_vlan         = 218
  provisioning_vlan = 219
}

module unallocated {
  source = "./modules/slot-config"

  # We've configured DHCP-provided fixed IPs for NIC 2 of each box, so we'll let the
  # unallocaated machines connected to the lab RH Network on NIC 2 since that doesn't result
  # in any consumption from the DHCP pool.  We put the providioning NIC on a VLAN that isn't
  # used for any other slot as a way of parking it harmlessly.

  data_vlan         = 158
  provisioning_vlan = 230
}

module on_lab_network {
  source = "./modules/slot-config"
  data_vlan         = 158
  provisioning_vlan = 158
}

# -- Slot 00 ----------------------------------------

module fog01_sw_conn {
  source = "./modules/fog-sw-connections"

  machine_nr = 01
  slot       = module.slot_00.slot
}

module fog02_sw_conn {
  source = "./modules/fog-sw-connections"
  machine_nr = 02
  slot       = module.slot_00.slot
}

module fog03_sw_conn {
  source = "./modules/fog-sw-connections"
  machine_nr = 03
  slot       = module.slot_00.slot
}

module fog04_sw_conn {
  source = "./modules/fog-sw-connections"
  machine_nr = 04
  slot       = module.slot_00.slot
}

module fog05_sw_conn {
  source = "./modules/fog-sw-connections"
  machine_nr = 05
  slot       = module.slot_00.slot
}

module fog06_sw_conn {
  source = "./modules/fog-sw-connections"
  machine_nr = 06
  slot       = module.slot_00.slot
}

# -- Slot 02 ----------------------------------------

module fog07_sw_conn {
  source = "./modules/fog-sw-connections"
  machine_nr = 07
  slot       = module.slot_02.slot
}

module fog08_sw_conn {
  source = "./modules/fog-sw-connections"
  machine_nr = 08
  slot       = module.slot_02.slot
}

module fog09_sw_conn {
  source = "./modules/fog-sw-connections"
  machine_nr = 09
  slot       = module.slot_02.slot
}

module fog10_sw_conn {
  source = "./modules/fog-sw-connections"
  machine_nr = 10
  slot       = module.slot_02.slot
}

module fog11_sw_conn {
  source = "./modules/fog-sw-connections"
  machine_nr = 11
  slot       = module.slot_02.slot
}

module fog12_sw_conn {
  source = "./modules/fog-sw-connections"
  machine_nr = 12
  slot       = module.slot_02.slot
}

# -- Slot 04 ----------------------------------------

module fog13_sw_conn {
  source = "./modules/fog-sw-connections"
  machine_nr = 13
  slot       = module.slot_04.slot
}

module fog14_sw_conn {
  source = "./modules/fog-sw-connections"
  machine_nr = 14
  slot       = module.slot_04.slot
}

module fog15_sw_conn {
  source = "./modules/fog-sw-connections"
  machine_nr = 15
  slot       = module.slot_04.slot
}

module fog16_sw_conn {
  source = "./modules/fog-sw-connections"
  machine_nr = 16
  slot       = module.slot_04.slot
}

module fog17_sw_conn {
  source = "./modules/fog-sw-connections"
  machine_nr = 17
  slot       = module.slot_04.slot
}

module fog18_sw_conn {
  source = "./modules/fog-sw-connections"
  machine_nr = 18
  slot       = module.slot_04.slot
}


# -- Slot 06 ----------------------------------------

module fog19_sw_conn {
  source = "./modules/fog-sw-connections"
  providers = {junos = junos.sw2}

  machine_nr = 19
  slot       = module.slot_06.slot
}

module fog20_sw_conn {
  source = "./modules/fog-sw-connections"
  providers = {junos = junos.sw2}

  machine_nr = 20
  slot       = module.slot_06.slot
}


module fog21_sw_conn {
  source = "./modules/fog-sw-connections"
  providers = {junos = junos.sw2}

  machine_nr = 21
  slot       = module.slot_06.slot
}

module fog22_sw_conn {
  source = "./modules/fog-sw-connections"
  providers = {junos = junos.sw2}

  machine_nr = 22
  slot       = module.slot_06.slot
}

module fog23_sw_conn {
  source = "./modules/fog-sw-connections"
  providers = {junos = junos.sw2}

  machine_nr = 23
  slot       = module.slot_06.slot
}

module fog24_sw_conn {
  source = "./modules/fog-sw-connections"
  providers = {junos = junos.sw2}

  machine_nr = 24
  slot       = module.slot_06.slot
}

# -- Unallocated ------------------------------------

