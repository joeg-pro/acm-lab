
# Some common functions for ACM Lab Fog-machine stuff.

# Assumes: Python 3.6+

import json
import sys

import os
import yaml

# Some message-emitting utilities.

dbg_volume_level = 0

def set_dbg_volume_level(lvl):
   global dbg_volume_level
   dbg_volume_level = lvl

def get_dbg_volume_level():
   return dbg_volume_level

def eprint(*args, **kwargs):
   print(*args, file=sys.stderr, **kwargs)

def emsg(msg, *args):
   eprint("Error: " + msg, *args)

def wmsg(msg, *args):
   eprint("Warning: " + msg, *args)

def nmsg(msg, *args):
   eprint("Note: " + msg, *args)

def blurt(*args, **kwargs):
   print(*args, **kwargs)

def die(msg, *args):
   eprint("Error: " + msg, *args)
   eprint("Aborting.")
   exit(2)

def dbg(msg, *args, level=1):
   if level <= dbg_volume_level:
      eprint("DBG: " + msg, *args)


def json_dumps(a_dict):
   return json.dumps(a_dict, indent=3, sort_keys=True)


# Some strang manipulation utils

def remove_trailing(s, ending):
   return s[:-len(ending)] if s.endswith(ending) else s

# Split a string into left and right parts based on the first occurrence of a
# delimiter encountered when scanning left to right. If the delimiter isn't
# found, the favor_right argument determines if the string is considered to
# be all right of the delimiter or all left of it.

def split_at(the_str, the_delim, favor_right=True):

   split_pos = the_str.find(the_delim)
   if split_pos > 0:
      left_part  = the_str[0:split_pos]
      right_part = the_str[split_pos+1:]
   else:
      if favor_right:
         left_part  = None
         right_part = the_str
      else:
         left_part  = the_str
         right_part = None

   return (left_part, right_part)


# Return entry from our lab machine info "database" (yaml file).

machine_info = None

def _load_machine_info_db(for_std_user=None):

   global machine_info

   if machine_info is not None:
      return

   # Get BMC address and creds from our machine info database (yaml files).

   machine_db_yaml = os.getenv("ACM_LAB_MACHINE_INFO")
   if machine_db_yaml is None:
      machine_db_yaml = os.getenv("FOG_MACHINE_INFO")
   if machine_db_yaml is None:
      die("Environment variable ACM_LAB_MACHINE_INFO is not set.")
   machine_creds_yaml = os.getenv("ACM_LAB_MACHINE_CREDS")
   if machine_creds_yaml is None:
      machine_creds_yaml = os.getenv("FOG_MACHINE_CREDS")
   if machine_creds_yaml is None:
      die("Environment variable ACM_LAB_MACHINE_CREDS is not set.")

   for_std_user = for_std_user if for_std_user is not None else "bmc"
   if for_std_user not in ["bmc", "default", "root", "admin", "mgmt"]:
      die("Requested standard user \"%s\"%s is not recognized." % for_std_user)

   # Load DB and convert it into a dict indexed by machine name.

   try:
      with open(machine_db_yaml, "r") as stream:
         machine_db = yaml.safe_load(stream)
   except FileNotFoundError:
      die("Machine info db file not found: %s" % machine_db_yaml)

   try:
      machine_info = {e["name"]: e for e in machine_db["machines"]}
   except KeyError:
      die("Machine info db not as expected (no machines list).")

   # Load creds into and merge into the machine db entries.

   try:
      with open(machine_creds_yaml, "r") as stream:
         creds_info = yaml.safe_load(stream)
   except FileNotFoundError:
      die("Machine creds db file not found: %s" % machine_creds_yaml)

   global_creds_entry = "bmc" if for_std_user == "bmc" else "bmc-%s" % for_std_user
   global_creds = None
   try:
      global_creds = creds_info["global"][global_creds_entry]
      global_username = global_creds["username"]
      global_password = global_creds["password"]
   except KeyError:
      die("Machine creds db does not have global creds for standard user \"%s\"." % for_std_user)
   # In Future, maybe we'll add per-machine cred overrides but none such for now.

   # Merge the creds into each machine_info entry if none already there.

   try:
      for m_entry in machine_info.values():
         bmc_info = m_entry["bmc"]
         if "username" not in bmc_info:
            bmc_info["username"] = global_username
         if "password" not in bmc_info:
            bmc_info["password"] = global_password

   except KeyError:
      die("Machine info db not as expected (bmc data missing/wrong).")

def get_machine_entry(machine_name, for_std_user=None):

   _load_machine_info_db(for_std_user=for_std_user)


   # Although the machine name key in the database isn't a hostname, we often
   # use it as the first component of a dotted fully-squalified hostname.
   # As a conveninece, accept it that form and use the first component as
   # the machine name.

   machine_name,junk = split_at(machine_name, ".", favor_right=False)

   try:
      return machine_info[machine_name]
   except KeyError:
      die("Machine %s not recored in machine info db." % machine_name)
   #

