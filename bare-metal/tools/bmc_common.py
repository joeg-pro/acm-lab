
# Some common functions for ACM Lab BMC (Redfish) stuff.

# Assumes: Python 3.6+

import json
import requests
import sys
import time
import urllib3


# For machine info db stuff:

import os
import yaml

urllib3.disable_warnings()

dbg_volume_level = 0

def set_dbg_volume_level(lvl):
   global dbg_volume_level
   dbg_volume_level = lvl

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

def remove_trailing(s, ending):
   return s[:-len(ending)] if s.endswith(ending) else s

def now():
   return time.time()

def _json_dumps(a_dict):
   return json.dumps(a_dict, indent=3, sort_keys=True)


class BMCError(Exception):
   pass

class BMCRequestError(BMCError):

   def __init__(self, connection, resp=None, msg=None):

      if msg is not None:
         self.message   = msg

      elif resp is not None:
         self.response  = resp
         self.status    = resp.status_code

         resp_json = {}
         if resp.text is not None:
            resp_content_type = resp.headers.get("content-type")
            resp_content_type = resp_content_type.split(";")[0]
            if resp_content_type  == "application/json":
               resp_json = resp.json()
         if "error" in resp_json:
            # Use extended error info if present.
            err = resp_json["error"]
            try:
               extended_info = err["@Message.ExtendedInfo"]
               if isinstance(extended_info, list):
                  extended_info = extended_info[0]
                  msg = extended_info["Message"]
            except KeyError:
               msg = err["message"]
         else:
            msg = "An unspecified BMC request error occurred."
         self.message   = msg

      else:
         if msg is not None:
            self.message = msg
         else:
            self.message = "An unknown error occurred."

   def __str__(self):
      return "Status %d: %s" % (self.status, self.message)

def _resp_json(resp):
   return dict() if resp.text == "" else resp.json()

class BMCConnection(object):

   # Note: We'll try to keep Dell-iDRAC specific sutff from creaping into this class
   # just in case we ever have any Redfish-managed machines from another hw vendor.
   # To do this, we'll refer to the Redfish spec in preference to (or as a sanity check
   # of) stuff found in the Dell iDRAC Redfish doc.

   def __init__(self, base_url, username, password):

      self.username = username
      self.password = password
      self.verify   = False

      self.base_url = remove_trailing(base_url, "/")

      # Get V1 root URL from the /redfish resource on the base URL given.

      self.rf_svc_root_uri = self.base_url
      version_obj = self.do_get("redfish", unauth=True)
      self.rf_svc_root_uri = remove_trailing(self.base_url + version_obj["v1"], "/")

      # Get the service root resource as we'll need it to form paths for other
      # collections/services we will use.

      self.svc_root_res = self.do_get(None, unauth=True)
      dbg("Service root resource:\n%s" % json.dumps(self.svc_root_res, sort_keys=True, indent=3), level=9)

      # Cache of resources we've fetched.
      self.resources = dict()

      # Some resource ids we may discover/learn as we need them.
      self.this_system_id          = None

   def _cache_resource(self, key, resource):

      msg_start = "Adding to" if key not in self.resources else "Updating in"
      dbg("%s resource cache: %s" % (msg_start, key), level=5)
      dbg("Resource contents: \n %s" % json.dumps(resource, indent=3), level=6)
      self.resources[key] = (now(), resource)

   def _get_resource(self, key):
      if key in self.resources:
         dbg("Getting resource from cache: %s" % key, level=5)
         return self.resources[key][1]
      else:
         res = self.do_get(key)
         self._cache_resource(key, res)
         return res

   def _get_collection(self, key, expand=0):
      query_parm = None
      if expand != 0:
         query_parm = {"$expand": ".($levels=%d)" % expand}
      coll = self.do_get(key, query_parms=query_parm)
      return coll

   def _check_for_error(self, resp):

      dbg("Response status: %d" % resp.status_code)

      # Note:  At least for Dell iDRAC, the HTTP status code 200 isn't reliable as it can
      # report status 200 for some error conditions.  So treat 2XX other than 200 as Ok
      # but we look deeper into the response for 200's.

      is_2xx = (resp.status_code // 100) == 2
      if is_2xx and resp.status_code != 200:
         return resp

      if resp.status_code == 200:
         if resp.text is None:
            return resp
         if "error" not in resp.json():
            return resp

      raise BMCRequestError(self, resp=resp)

   def redfish_request(self, method, resource_path, query_parms=None, body=None, headers=None, unauth=False):
      """
      Issue an Redfish request and return the response.  JSON input/output assumed.
      """

      # Normalize inputs.
      method = method.upper()
      hdrs = headers if headers is not None else dict()
      auth = None if unauth else (self.username, self.password)

      # Convert body to a JSON string.
      # bdy  = json.dumps(body) if body is not None else None

      # Build request URL.  If a resource path is specified and starts with a slash
      # we consider it absolue (relative to the base URI).  Otherwise we treat it
      # as relative to the service root URI.

      if resource_path is not None:
         resource_path = remove_trailing(resource_path, "/")
         if resource_path.startswith("/"):
            uri = self.base_url + resource_path
         else:
            uri = self.rf_svc_root_uri + "/" + resource_path
      else:
         uri = self.rf_svc_root_uri

      # Ask for JSON results, and indicate we're sending JSON if we are.

      hdrs["accept"] = "application/json"
      if method in ["PUT", "PATCH", "POST"]:
         hdrs["content-type"] = "application/json"

      creds = None if unauth else (self.username, self.password)

      if method == "GET":
         qp = ""
         if query_parms is not None:
            qp = " (Query Parms: %s)" % query_parms
         dbg("GETting URI: %s%s" % (uri, qp), level=4)
         resp = requests.get(uri, params=query_parms, verify=self.verify, auth=creds)

      elif method == "POST":
         dbg("POSTing to URI: %s" % uri, level=4)
         if body is not None:
            dbg("   with JSON body:\n %s" % json.dumps(body, sort_keys=True), level=4)
         resp = requests.post(uri, verify=self.verify, auth=creds, json=body, headers=hdrs)

      elif method == "PATCH":
         dbg("PATCH not implemented yet.")
         pass
      return (self._check_for_error(resp))

   def do_get(self, resource_path, unauth=False, query_parms=None):

      resp = self.redfish_request("GET", resource_path, query_parms=query_parms, unauth=unauth)
      return _resp_json(resp)

   def do_post(self, resource_path, body=None):
      return _resp_json(self.redfish_request("POST", resource_path, body=body))

   def _get_sys_collection_path(self):
      # Probably: /redfish/v1/Systems/
      return self.svc_root_res["Systems"]["@odata.id"]

   def _get_mgr_collection_path(self):
      # Probably: /redfish/v1/Managers
      return self.svc_root_res["Managers"]["@odata.id"]

   def _get_acct_svc_path(self):
      # Probably: /redfish/v1/AccountService
      return self.svc_root_res["AccountService"]["@odata.id"]

   def _get_acct_svc_resource(self):
      res_path = self._get_acct_svc_path()
      return self._get_resource(res_path)

   def _get_acct_collection_path(self):
      # Probably: /redfish/v1/AccountService/Accounts
      res = self._get_acct_svc_resource()
      return res["Accounts"]["@odata.id"]

   def _get_this_system_id(self):
      if self.this_system_id is not None:
         return self.this_system_id

      # Since the Redfish service we're connected to is that provided by MC (vs. a
      # multi-system management facility), it stands to reaosn there should only be
      # one System resource.  So find it from the Systems collection.

      sys_collection = self.do_get(self._get_sys_collection_path())
      members = sys_collection["Members"]
      if len(members) != 1:
         how_many = "No" if len(members) == 0 else "Multiple"
         raise BMCRequestError(self, msg="%s Computer Systems found." % how_many)

      # Members is an array of objects with at least an @odata.id property.
      self.this_system_id = members[0]["@odata.id"]
      dbg("Determined this system id: %s" % self.this_system_id, level=3)
      return self.this_system_id

   def get_this_system_resource(self):
      res_path = self._get_this_system_id()
      return self._get_resource(res_path)

   def _get_accounts(self, want_user_name=None, find_first_empty_slot=False):

      # NB: This internal function is a hybrid thing that returns either a dict of
      # account resources ndexed by name or a single account resource depending on
      # parameters:
      #
      # (1) If both want_user_name and find_first_empty_slot are None/Default,
      #     it returns an indexed dict of all account resources.
      # (2) If want_user_name is set then:
      #     (a) If the desired account is found it is returned.
      #     (b) If the desired account is not found then:
      #         (1) If find_first_empty_slot is false, None is returned.
      #         (2) If find_first_empty_slit is true, ad there is an empty account
      #             slot it is returned.  Otherwise None is returned.
      #
      # Yep, this is a strange  (maybe gross)  combination of functions and maybe makes this
      # confusing and hard to maintain.  Blame this on perhaps an ill-advised attempt to have
      # common code.

      used_as_internal_util= want_user_name is not None or find_first_empty_slot
      dbg_msg_lvl         = 9 if used_as_internal_util else 1
      dbg_msg_lvl_verbose = 9 if used_as_internal_util else 3

      quit_when_empty_slot_found = find_first_empty_slot and want_user_name is None
      return_empty_slot = find_first_empty_slot

      dbg("Getting all defined BMC accounts.", level=dbg_msg_lvl)
      col_path = self._get_acct_collection_path()

      # Sign: $exapnd doesn't work on iDRAC.  Getting 404 error re last entry in collection.
      # accts_collection = self._get_collection(col_path, expand=1)
      accts_collection = self._get_collection(col_path)

      accounts = dict()
      members = accts_collection["Members"]
      empty_slot = None
      for m in members:
         member_path = m["@odata.id"]
         acct_res = self._get_resource(member_path)
         user_name = acct_res["UserName"]
         if user_name != "":
            dbg("Found account for user \"%s\"" % user_name, level=dbg_msg_lvl)
            dbg("Account details:\n%s" % _json_dumps(acct_res), level=dbg_msg_lvl_verbose)
            accounts[user_name] = acct_res
            if user_name == want_user_name:
               # We found the user that was really wanted. Return just it.
               dbg("Found account for the user we were interested in.", level=dbg_msg_lvl)
               return acct_res
            #
         else:
            id = int(acct_res["Id"])
            if id > 1 and empty_slot is None:
               # We found an empty slot.  Save it.
               dbg("Found first empty account slot at id %d." % id, level=dbg_msg_lvl)
               empty_slot = acct_res
               if quit_when_empty_slot_found:
                  return empty_slot
            #
         #
      #

      if not used_as_internal_util:
         return accounts

      if find_first_empty_slot:
         return empty_slot
      else:
         return None

   def get_all_accounts(self):
      return self._get_accounts()

   def get_account(self, user_name):
      dbg("Getting BMC account for user \"%s\"" % user_name, level=1)
      acct_res = self._get_accounts(want_user_name=user_name)
      if acct_res is not None:
         dbg("%s" % _json_dumps(acct_res), level=3)
         return acct_res
      else:
         dbg("BMC account for user \"%s\" not found." % user_name, level=1)
         return None

   def add_account(self, user_name):

      # Make sure the account doesn't already exist.
      acct_res = self._get_accounts(want_user_name=user_name, find_first_empty_slot=True)

      # If we get None back, it means the account didn't already exist (good), but
      # we also have no empty slot to add a new one.

      if acct_res is not None:
         raise BMCRequestError(self, msg="No room available for new account \"%s\"." % user_name)

      res_user_name = acct_res["UserName"]
      if res_user_name == user_name:
         raise BMCRequestError(self, msg="Account \"%s\" already exists." % user_name)

      dbg("Will create new account using slot at id %d" % acct_res["id"])


   def get_power_state(self):
      ''''
      Get power state from the Computer System resource for this system/BMC.
      '''

      res = self.get_this_system_resource()
      return res["PowerState"]

   def _do_system_reset_action(self, action_type):

      # GEt the URI path for the ComputerSystem.Reset action.

      res = self.get_this_system_resource()
      supported_actions = res["Actions"]
      try:
         action = supported_actions["#ComputerSystem.Reset"]
      except KeyError:
         raise BMCRequestError(self, msg="Computer System doesn't provide a Reset action")

      action_path = action["target"]
      supported_action_types = action["ResetType@Redfish.AllowableValues"]
      if action_type not in supported_action_types:
         raise BMCRequestError(self, msg="Computer System doesn't support Reset action type %s" % action_type)

      dbg("Resetting system (type: %s)" % action_type, level=1)
      dbg("SYstem Reset - Action Path: %s" % action_path, level=3)

      post_body = {"ResetType": action_type}
      self.do_post(action_path, post_body)

      # TODO: Remove system resource from cache since we've changed it.

   def system_power_on(self):
      dbg("Processing system power-on request.", level=1)
      power_state = self.get_power_state()
      dbg("Current power state: %s" % power_state, level=2)
      if power_state.lower() != "on":
         self._do_system_reset_action("On")
      else:
         nmsg("System was already powered ON.")

   def system_power_off(self):
      dbg("Processing system power-off request.", level=1)
      power_state = self.get_power_state()
      dbg("Current power state: %s" % power_state, level=2)
      if power_state.lower() != "off":
         self._do_system_reset_action("ForceOff")
      else:
         nmsg("System was already powered OFF.")

class DellBMCConnection(BMCConnection):

   def __init__(self, hostname, username, password):

      # NB: Dell iDRAC's Redfish implementation only supports https connections.
      base_url = "https://%s" % hostname
      super().__init__(base_url, username, password)


class FogBMCConnection(object):

   # Notes:
   # - This class contains a (Dell) BMC Connection object rather than subclasses
   #   from it in case we have non-Dell hardware in the future and we want this
   #   class to act as a fascade over all kinds.

   def __init__(self, fog_name, username=None, password=None):

      self.machine_info = None
      bmc_cfg = self._get_bmc_cfg(fog_name)

      self.host = bmc_cfg["address"]
      self.username = bmc_cfg["username"] if username is None else username
      self.password = bmc_cfg["password"] if password is None else password
      # Future: Maybe also accept username/password from env vars?

      self.connection = DellBMCConnection(self.host, self.username, self.password)

      self.get_power_state  = self.connection.get_power_state
      self.system_power_on  = self.connection.system_power_on
      self.system_power_off = self.connection.system_power_off

      self.get_all_accounts = self.connection.get_all_accounts
      self.get_account      = self.connection.get_account
      self.add_account      = self.connection.add_account

   def _load_machine_info_db(self):

      if self.machine_info is not None:
         return
      # Get BMC address and creds from our machine info database (yaml files).

      machine_db_yaml = os.getenv("FOG_MACHINE_INFO")
      if machine_db_yaml is None:
         die("Environment variable FOG_MACHINE_INFO is not set.")
      machine_creds_yaml = os.getenv("FOG_MACHINE_CREDS")
      if machine_creds_yaml is None:
         die("Environment variable FOG_MACHINE_CREDS is not set.")

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

      global_creds = None
      try:
         global_creds = creds_info["global"]["bmc"]
         global_username = global_creds["username"]
         global_password = global_creds["password"]
      except KeyError:
         die("Machine creds db not as expected (global.bmc data missing/incomplete).")
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

      self.machine_info = machine_info

   def _get_bmc_cfg(self, machine_name):

      self._load_machine_info_db()

      m_entry = None
      bmc_cfg = {}
      try:
         m_entry = self.machine_info[machine_name]
         bmc_info = m_entry["bmc"]
         bmc_cfg["address"]  = bmc_info["address"]
         bmc_cfg["username"] = bmc_info["username"]
         bmc_cfg["password"] = bmc_info["password"]
      except KeyError:
         if m_entry is None:
            die("Machine %s not recored in machine info db." % machine_name)
         else:
            die("Machine info db not as expected (bmc data missing/wrong).")

      return bmc_cfg

