#!/bin/python3

# Gathers info needed for a lab machine-info db entry.

# Author: J. M. Gdaniec, Nov 2021

from lab_common import *

import argparse
import traceback

def main():

   set_dbg_volume_level(1)

   parser = argparse.ArgumentParser()
   parser.add_argument("machine" )
   LabBMCConnection.add_bmc_login_argument_definitions(parser)

   args = parser.parse_args()

   machine   = args.machine

   bmc_conn = LabBMCConnection.create_connection(machine, args)

   fog_name = machine
   is_single_node_machine = fog_name.startswith("fog")

   # Get the system resource.  From there, get the Chassis that holds physical resources.
   #
   # Note: we assume there is only one Chassis entry, which probably would break if the system
   # were an element of a aggregation chassis, like a Blade in a BladeCenter.

   sys_res_id = "/redfish/v1/Systems/System.Embedded.1"
   sys_res = bmc_conn.get_resource(sys_res_id)

   s_mfg = sys_res["Manufacturer"]
   s_model = sys_res["Model"]

   supported_mfgs = ["Dell Inc."]
   supported_models = ["PowerEdge R340", "PowerEdge R640", "PowerEdge R740"]

   if s_mfg not in supported_mfgs or s_model not in supported_models:
      emsg("This script does not support %s %s systems." % (s_mfg, s_model))
      exit(3)

   dell_service_tag = sys_res["Oem"]["Dell"]["DellSystem"]["NodeID"]

   dbg("System: %s - %s (%s)" % (s_mfg, s_model, dell_service_tag), level=2)

   chassis_id = sys_res["Links"]["Chassis"][0]["@odata.id"]
   chassis_res = bmc_conn.get_resource(chassis_id)

   # Get the collection of network adpates.

   net_adapter_coll_id = chassis_res["NetworkAdapters"]["@odata.id"]
   net_adapters = bmc_conn.get_collection_members(net_adapter_coll_id)

   # Collect up info for each network adapter/port we find.  We'll sort though
   # them and produce machine-info entries in a second pass.

   net_ports = list()

   for na in net_adapters:
      na_just_id = na["Id"]
      na_mfg = na["Manufacturer"]
      na_model = na["Model"]

      dbg("Network Adapter %s: %s - %s" % (na_just_id,na_mfg, na_model), level=2)
      # NB: There is no Dell OEM extension in the Network Adapter resource, nor
      # does there seem to be vendor, slot etc. info in the resource.

      ## print(json_dumps(na))

      # For each, get the list of network functions, each of which will represent
      # an Ethernet NIC (for Ethernet card), or a FiberChannel port (for FC card).

      net_func_coll_id = na["NetworkDeviceFunctions"]["@odata.id"]
      net_funcs = bmc_conn.get_collection_members(net_func_coll_id)
      for nf in net_funcs:
         nf_id = nf["@odata.id"]
         nf_just_id = nf["Id"]
         nf_type = nf["NetDevFuncType"]
         dell_info = nf["Oem"]["Dell"]

         net_port = dict()

         if nf_type == "Ethernet":
            dbg("Ethernet function %s:" % nf_just_id, indent_level=1, level=2)
            net_port["id"] = nf_just_id
            net_port["type"] = nf_type
            nf_eth = nf["Ethernet"]
            dell_nic = dell_info["DellNIC"]

            product_name = dell_nic["ProductName"]
            vendor_name  = dell_nic["VendorName"]
            pci_vendor_id = dell_nic["PCIVendorID"]
            pci_device_id = dell_nic["PCIDeviceID"]

            # On R340, av least, if a NIC card is disabled these properties ren't available:

            pci_vendor_id = pci_vendor_id if pci_vendor_id != "" else "Not Available"
            pci_device_id = pci_device_id if pci_device_id != "" else "Not Available"

            dbg("Vendor: %s" % vendor_name, indent_level=2, level=2)
            dbg("Product: %s" % product_name, indent_level=2, level=2)
            dbg("PCI Vendor Id: %s" % pci_vendor_id, indent_level=2, level=2)
            dbg("PCI Device Id: %s" % pci_device_id, indent_level=2, level=2)
            net_port["vendor_name"] = vendor_name
            net_port["product_name"] = product_name
            net_port["pci_vendor_id"] = pci_vendor_id
            net_port["pci_device_id"] = pci_device_id

            port_asgn_id = nf["Links"]["PhysicalPortAssignment"]["@odata.id"]
            port = bmc_conn.get_resource(port_asgn_id)
            phys_port_nr = port["PhysicalPortNumber"]

            dbg("Phys Port Nr: %s"  % phys_port_nr, indent_level=2, level=2)
            net_port["phys_port_nr"] = phys_port_nr

            if nf_eth is not None:
               mac_addr = nf_eth["MACAddress"]
               dbg("MAC Address: %s" % mac_addr, indent_level=2, level=2)
               net_port["mac_addr"] = mac_addr

         elif nf_type == "FibreChannel":
            dbg("FiberChannel function %s:" % nf_just_id, indent_level=1, level=2)
            nf_fc = nf["FibreChannel"]
            dell_fc = dell_info["DellFC"]
            func_nr = dell_fc["Function"]   # Zero origin.

            device_name = dell_fc["DeviceName"]
            dbg("Device Name: %s" % device_name, indent_level=2, level=2)

            if nf_fc is not None:
               nf_wwpn = nf_fc["WWPN"]
               dbg("WWPN: %s" % nf_wwpn, indent_level=2)
         else:
            dbg("Skipping other (%s) function %s" % (nf_type, nf_just_id), indent_level=1, level=2)

         if net_port:
            net_ports.append(net_port)
         dbg("", level=2)
   #

   # Reprocess the raw network-port info based on what we expect on our various machines.

   # On R340s, we expect at most one of each of these:
   #
   # Broadcom Corp/Broadcom Gigabit Ethernet BCM5720
   # Intel Corp/X710 10GbE Controller
   #
   # On R640/R740s, we expect at most one of each of these:
   #
   # Intel Corp/Intel(R) Gigabit 4P I350-t rNDC - E4:43:4B:50:0C:30
   # Intel Corp/Intel(R) Ethernet Converged Network Adapter X710 - F8:F2:1E:8B:4B:E0
   #
   # PCI Vendor Ids of relevance:
   #
   # 14e4 = Broadcom
   # 8086 = Intel Corp
   #
   # Device Ids:
   #
   # 165f = Broadcom Gigabit Ethernet BCM5720 (as in R340)
   # 1521 = Intel(R) Gigabit 4P I350-t rNDC (as in R740)
   # 1572 = Intel(R) Ethernet Converged Network Adapter X710 (as in R740)

   ge_nic_info = list()
   xe_nic_info = list()

   lab_nic_nr = 2 if is_single_node_machine else 1

   for net_port in net_ports:

      if net_port["type"] != "Ethernet":
         continue

      pci_vendor_id = net_port["pci_vendor_id"]
      pci_device_id = net_port["pci_device_id"]
      phys_port_nr  = net_port["phys_port_nr"]

      try:
         mac_addr = net_port["mac_addr"]
      except KeyError:
         # If we didn't find a MAC address, its probably a disabled NIC
         # on an R340.  Skip it.
         continue

      a_nic = dict()

      if pci_vendor_id == "14e4":
         # Broadcom devices

         if pci_device_id == "165f":

            # This is one of the 1 Gb NICs in an R340.  Map to NIC1/2 based on
            # the physica port id. These will be visible to the operating system
            # as eno1/2 based on physicap port number.
            #
            # Declare connected to lab network if port nr matches lab_port_nr.

            nic_id = int(phys_port_nr)
            a_nic["id"] = nic_id
            a_nic["type"] = "ge"
            a_nic["device_name"] = "/dev/eno%s" % nic_id
            a_nic["mac_address"] = mac_addr

            connected_to_lab = True if nic_id == lab_nic_nr else False
            use_for_lab = connected_to_lab
            a_nic["connected_to_lab_network"] = connected_to_lab
            a_nic["use_for_lab_networking"] = use_for_lab

            ge_nic_info.append(a_nic)

      elif pci_vendor_id == "8086":

         if pci_device_id == "1521":

            # This is one of the 1 Gb NICs on the 4-port i350 NDC of an R640/R740.
            # Map to NIC1/2/3/4 based on the physica port id.  These will be visble
            # to the OS as xxxxxxx based on physical port number.
            #
            # Declare connected to lab network if port nr matches lab_port_nr.

            nic_id = int(phys_port_nr)
            a_nic["id"] = nic_id
            a_nic["type"] = "ge"
            a_nic["device_name"] = "/dev/enpxyz%s" % nic_id
            a_nic["mac_address"] = mac_addr

            connected_to_lab = True if nic_id == lab_nic_nr else False
            use_for_lab = connected_to_lab
            a_nic["connected_to_lab_network"] = connected_to_lab
            a_nic["use_for_lab_networking"] = use_for_lab

            ge_nic_info.append(a_nic)

         elif pci_device_id == "1572":

            # This is one of the 10Gb NICs on the 2-port X710 SFP+ add-in card on our
            # R640 and R740s.  Map to 10Gb NIC 1/2 based on physical port number.
            # These will be visible to the OS as xxxxxxx based on physical port number.
            #
            # Our 10Gb NICs are never connected to the lab network.

            nic_id = int(phys_port_nr)
            a_nic["id"] = nic_id
            a_nic["type"] = "xe"
            a_nic["device_name"] = "/dev/need-to-figure-out"
            a_nic["mac_address"] = mac_addr

            connected_to_lab = False
            use_for_lab = connected_to_lab
            a_nic["connected_to_lab_network"] = connected_to_lab
            a_nic["use_for_lab_networking"] = use_for_lab

            xe_nic_info.append(a_nic)

      else:
         pass
   #

   # Make machine-info entry...

   entries = list()
   entry = dict()
   entries.append(entry)

   entry["name"] = fog_name
   entry["service_tag"] = dell_service_tag

   bmc_info = dict()
   entry["bmc"] = bmc_info
   bmc_info["address"] = "%s-drac.mgmt.acm.lab.eng.rdu2.redhat.com" % fog_name
   bmc_info["redfish"] = "%s-drac.mgmt.acm.lab.eng.rdu2.redhat.com/redfish/v1/Systems/System.Embedded.1" % fog_name

   lab_networking = dict()

   ip_addr_last_octet = "99"  # XXX Maybe take as a script argument?

   if ge_nic_info:
      nic_info = dict()
      entry["nics"] = nic_info

      for a_nic in ge_nic_info:
         nic_id = a_nic["id"]
         nic_info["nic%s" % nic_id] = a_nic

         if a_nic["use_for_lab_networking"]:
            ln_info = dict()
            ln_info["for_nic_id"] = nic_id
            ln_info["dhcp_ip_address"] = "10.1.158.%s" % ip_addr_last_octet
            ln_info["fqhn"] = "%s.acm.lab.eng.rdu2.redhat.com" % fog_name
            lab_networking["nic%s" % nic_id] = ln_info
   #

   if xe_nic_info:
      nic_info = dict()
      entry["xe_nics"] = nic_info

      for a_nic in xe_nic_info:
         nic_id = a_nic["id"]
         nic_info["nic%s" % nic_id] = a_nic

   # Add lab-netowkring info if any NICs are defined for use on tha tnetwork.
   if lab_networking:
      entry["eng_lab_networking"] = lab_networking

   # Add OCP-cluster-provisioning  info only for OCP-Single-Node machines:

   if is_single_node_machine:
      cluster_networking = dict()
      entry["cluster_internal_networking"] = cluster_networking
      cn_info = dict()
      cluster_networking["nic2"] = cn_info
      cn_info["for_nic_id"] = 2
      cn_info["dhcp_ip_address"] = "172.31.0.%s" % ip_addr_last_octet
      cn_info["fqhn"] = "%s.cluster.internal" % fog_name

      entry["root_device_name"] = "/dev/sda"

   print(yaml.dump(entries, sort_keys=False))

if __name__ == "__main__":
   try:
      main()
   except BMCRequestError as exc:
      die(str(exc))
   except Exception:
      traceback.print_exc()
      die("Unhandled exception!")

