#!/bin/python3

#
# This is Highly DELL-iDRAC Specific.
#
# Author: J. M. Gdaniec, Apr 2021

from bmc_common import *

import argparse
import base64
import time
import traceback

import xml.etree.ElementTree as et


# Some XML parsing helpers

def x_ns_of(n):
   # Return the namespace qualifier of a tag/attribute name
   ns, _, _ = n.rpartition('}')
   if len(ns) > 0:
      ns = ns[1:]
   return ns

def x_type_of(n):
   # Return the plain type of a tag/attribute name
   _, _, ty = n.rpartition('}')
   return ty

def get_child_element_of_type(elem, elem_type):

   for child_elem in elem:
      if x_type_of(child_elem.tag) == elem_type:
         return child_elem
   return None

def get_attributet_of_type(elem, attr_type):

   for k, v in elem.attrib.items():
      if x_type_of(k) == attr_type:
         return v
   return None


def do_the_thing_for_machine(machine):

   what_action = "Installing" if installing_license else "Removing"

   blurt("%s license for %s on machine %s." % (what_action, target_license_descr, machine))
   bmc_conn = LabBMCConnection.create_connection(machine, args, default_to_admin=True)

   # Figure out the vendor that made this system.

   service_root_res = bmc_conn.get_service_root_resource()
   vendor = service_root_res["Vendor"]
   if vendor != "Dell":
      emsg("Machine %s is an unsupported %s systen." % vendor)
      return 5

   # Get info about the BMC that manages the System whose BMC we're connected to.

   sys_mgr_res = bmc_conn.get_system_manager_resource()

   bmc_inst_id = sys_mgr_res["Id"]
   dell_oem_links = sys_mgr_res["Links"]["Oem"][vendor]
   dell_license_coll_id = dell_oem_links["DellLicenseCollection"]["@odata.id"]
   dell_license_mgr_service_id = dell_oem_links["DellLicenseManagementService"]["@odata.id"]

   target_license = None

   dell_license_ids = bmc_conn.get_collection_member_ids(dell_license_coll_id)
   for dell_license_id in dell_license_ids:
      dell_license = bmc_conn.get_resource(dell_license_id)
      if bmc_inst_id in dell_license["AssignedDevices"]:
         l_entitlement_id = dell_license["EntitlementID"]
         if l_entitlement_id == target_entitlement_id:
            target_license = dell_license
            break
   #

   license_mgr_svc     = bmc_conn.get_resource(dell_license_mgr_service_id)
   license_mgr_actions = license_mgr_svc["Actions"]

   if installing_license:

      # Complain if the license is already installed.

      if target_license is not None:
         l_type = dell_license["LicenseType"]
         l_descr = dell_license["LicenseDescription"][0]
         if l_type == "Evaluation":
            l_remaining_days = dell_license["EvalLicenseTimeRemainingDays"]
            if l_remaining_days == 0:
               m_text = "Expired evaluation license for %s already installed on this system."
               m_args = target_license_description
            else:
               m_text = "Active evaluation license for %s already installed on this system (%d days remaining)."
               m_args = (l_descr, l_remaining_days)
         else:
            m_text = "%s license for %s already installed on this ssytem.."
            m_args = (l_type, l_descr)
         wmsg(m_text % m_args)
         return 1

      # License not already present, install (import) it....

      # Base64 encode the license data.

      l_contents_bytes     = license_contents.encode("UTF-8")
      l_contents_b64_bytes = base64.b64encode(l_contents_bytes)
      l_contents_b64       = l_contents_b64_bytes.decode("ascii")

      # iDRAC doesn't like single-line base64 encodings, but will actept stuff
      # as encoded by the base64 utility with default wrapping.  So split the
      # base64 utility into lines of no more than 76 chars.

      ll = 76
      l_contents_b64_l76 = ""
      for ix in range(0, len(l_contents_b64), ll):
         if ix > 0:
            l_contents_b64_l76 += "\n"
         l_contents_b64_l76 = l_contents_b64_l76 + l_contents_b64[ix:ix+ll]

      import_action_target = license_mgr_actions["#DellLicenseManagementService.ImportLicense"]["target"]

      import_body = {"FQDD": bmc_inst_id,"ImportOptions": "Force","LicenseFile": l_contents_b64_l76}
      resp = bmc_conn.perform_action(import_action_target, import_body)

      blurt("License %s [%s] was successfully installed." % (target_license_descr, target_entitlement_id))

   elif removing_license:

      # Complain if the license is not already installed.

      if target_license is None:
         emsg("License for %s is not installed on this system." % target_license_descr)
         return 4

      # License exists.  Remove it.

      l_descr = target_license["LicenseDescription"][0]

      delete_action_target = license_mgr_actions["#DellLicenseManagementService.DeleteLicense"]["target"]
      delete_body = {"FQDD": bmc_inst_id,"DeleteOptions": "Force", "EntitlementID": target_entitlement_id}

      resp = bmc_conn.perform_action(delete_action_target, delete_body)
      blurt("License %s [%s] was successfully removed." % (l_descr, target_entitlement_id))

   return 0

def main():

   global args, target_entitlement_id, target_license_descr, license_contents
   global installing_license, removing_license

   set_dbg_volume_level(0)

   parser = argparse.ArgumentParser()
   LabBMCConnection.add_bmc_login_argument_definitions(parser)

   sub_parsers = parser.add_subparsers(dest="action")

   import_parser = sub_parsers.add_parser("install")
   import_parser.add_argument("license_file")
   import_parser.add_argument("machines", nargs="+")

   delete_parser = sub_parsers.add_parser("remove")
   delete_parser.add_argument("license_file")
   delete_parser.add_argument("machines", nargs="+")

   global args
   args = parser.parse_args()

   action = args.action
   if action is None:
      parser.parse_args(["-h"])
      exit(5)

   machines = {m: None for m in args.machines}
   license_file_path = args.license_file

   installing_license = (action == "install")
   removing_license   = not installing_license

   try:
      with open(license_file_path, mode="r", encoding="utf-8") as f:
         license_contents = f.read()
   except FileNotFoundError:
      emsg("License file %s not found." % license_file_path)
      exit(4)

   # Parse the License XML to extract some information we need.

   x_license_root = et.fromstring(license_contents)

   # Make sure the schema is what we expect.
   ok = False
   if x_ns_of(x_license_root.tag) != "http://www.dell.com/2011/12G/licensing":
      emsg("Unrecognized Dell License schema.")
      exit(4)

   # The structure we're parsing should look like:
   #
   # <LicenseClass>
   #   <LicenseData>
   #      ...
   #      <DeviceClass ID="iDRAC"/>
   #      ...
   #      <EntitlementID>some-entitlement-id</EntitlementID>
   #      ...
   #      <ProductDescription>
   #         ...
   #         <lang_en>OpenManage Enterprise Advanced</lang_en>
   #         ...
   #      </ProductDescription>
   #      ...
   #   </LicenseData>
   # </LicenseClass>

   x_license_data = x_license_root[0]

   # Look for the ProductDescription and EntitlementID elements of the LicenseData

   x_dev_class      = get_child_element_of_type(x_license_data, "DeviceClass")
   x_entitlement_id = get_child_element_of_type(x_license_data, "EntitlementID")
   x_prod_descr     = get_child_element_of_type(x_license_data, "ProductDescription")

   target_entitlement_id = x_entitlement_id.text
   target_dev_class_id = get_attributet_of_type(x_dev_class, "ID")

   # Find the English product description

   x_en_prod_descr      = get_child_element_of_type(x_prod_descr, "lang_en")
   target_license_descr = x_en_prod_descr.text

   # Do the license action across all of the machines.

   worst_rc = 0
   for machine in machines:
      rc = do_the_thing_for_machine(machine)
      worst_rc = max(worst_rc, rc)

   exit(worst_rc)

if __name__ == "__main__":
   try:
      main()
   except BMCRequestError as exc:
      die(str(exc))
   except Exception:
      traceback.print_exc()
      die("Unhandled exception!")

