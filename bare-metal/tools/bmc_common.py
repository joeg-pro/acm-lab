
# Some common functions for ACM Lab BMC (Redfish) stuff.

# Assumes: Python 3.6+

import json
import requests
import sys
import time
import urllib3

from lab_common import *

urllib3.disable_warnings()


def now():
   return time.time()

def _get_resource_id(res):
   return res["@odata.id"]

def json_dumps(thing):
   return json.dumps(thing, indent=3, sort_keys=True)

class BMCError(Exception):
   pass

class BMCRequestError(BMCError):

   def __init__(self, connection, resp=None, msg=None):

      if msg is not None:
         self.message   = msg
         self.status    = None

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
      if self.status is None:
         return self.message
      else:
         return "Status %d: %s" % (self.status, self.message)

def _resp_json(resp):
   return dict() if resp.text == "" else resp.json()


# All Redfish task states:
#
# New, Pending
# Service
# Starting, Running, Stopping, Completed
# Cancelling, Cancelled
# Exception, Interrupted, Interrupted
# Suspended
#
# Ref: http://redfish.dmtf.org/schemas/DSP2046_2019.1.html  (Vers s2019.1)

_task_states_waiting = ["New", "Pending"]
_task_states_in_prog = ["Service", "Running", "Starting", "Stopping", "Cancelling"]
_task_states_paused  = ["Suspended"]
_task_states_final   = ["Completed", "Cancelled",  "Exception", "Interrupted", "Killed"]
_task_state_normal_completion = ["Completed"]

def task_is_waiting(task_res):
   return task_res["TaskState"] in _task_states_waiting

def task_has_ended(task_res):
   return task_res["TaskState"] in _task_states_final

def task_is_in_progress(task_res):
   return task_res["TaskState"] in _task_states_in_prog

def task_competed_normally(task_res):
   return task_res["TaskState"] in _task_state_normal_completion

class BMCConnection(object):

   # Note: We'll try to keep Dell-iDRAC specific sutff from creaping into this class
   # just in case we ever have any Redfish-managed machines from another hw vendor.
   # To do this, we'll refer to the Redfish spec in preference to (or as a sanity check
   # of) stuff found in the Dell iDRAC Redfish doc.

   def __init__(self, base_url, username, password):

      dbg("Initializing BMCConnection object.", level=9)

      self.username = username
      self.password = password
      self.verify   = False

      self.session_token  = None
      self.session_res_id = None

      self.last_response = None

      # Debug message levels for various kinds of things.

      self.dbg_msg_lvl_api_summary = 1
      self.dbg_msg_lvl_rf_requests = 6

      # Cache of resources we've fetched.
      self.resources = dict()

      # Some resource ids we may discover/learn as we need them.
      self.this_system_id          = None

      self.base_url = remove_trailing(base_url, "/")

      # Get V1 root URL from the /redfish resource on the base URL given.

      self.rf_svc_root_uri = self.base_url
      version_obj = self.do_get("redfish", unauth=True)
      self.rf_svc_root_uri = remove_trailing(self.base_url + version_obj["v1"], "/")

      # Get the service root resource as we'll need it to form paths for other
      # collections/services we will use.

      self.svc_root_res = self.do_get(None, unauth=True)
      self._cache_resource(self.svc_root_res)
      dbg("Service root resource:\n%s" % json_dumps(self.svc_root_res), level=9)

      self._open_session()

   def __del__(self):

      dbg("Destroying BMCConnection object.", level=9)
      self._close_open_sessions()

   def _open_session(self):

      dbg_msg_lvl = self.dbg_msg_lvl_rf_requests

      dbg("Opening new session to BMC.", level=dbg_msg_lvl)

      sessions_coll_id = self._get_session_collection_path()

      req_body = {"UserName": self.username, "Password": self.password}
      session_res = self.do_post(sessions_coll_id, body=req_body, unauth=True)

      # Per info on RedFish session authentication, we may or may not get a response body back
      # from the POST, and even if we do, it won't contain the session token.  But the session id
      # (which we need to save to close/DELETE the session) and the token are always provided
      # in response headers.

      resp_hdrs = self.last_response.headers
      self.session_res_id = resp_hdrs["Location"]
      self.session_token  = resp_hdrs["X-Auth-Token"]

      dbg("Session open, session id: %s" % self.session_res_id, level=dbg_msg_lvl)
      # dbg("Session token: %s"% self.session_token, level=dbg_msg_lvl)

   def _close_open_sessions(self):

      dbg_msg_level = self.dbg_msg_lvl_rf_requests

      if self.session_res_id is not None:
         dbg("Closing open BMC session %s." % self.session_res_id, level=dbg_msg_level)
         try:
            self.do_delete(self.session_res_id)
         except BMCError:
            dbg("BMC exception raised during open-session closing. Ignoring.", level=dbg_msg_level)


   def _check_for_error(self, resp):

      # dbg("Response status: %d" % resp.status_code)

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

      dbg_msg_lvl = self.dbg_msg_lvl_rf_requests

      # Normalize inputs.
      method = method.upper()
      hdrs = headers.copy() if headers is not None else dict()
      auth = None if unauth else (self.username, self.password)

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
         hdrs["content-type"] = "application/json;charset=utf-8"

      creds = None
      if not unauth:
         # Use session token is a session is estbalished, otherwise basic auth.
         if self.session_token is not None:
            hdrs["X-Auth-Token"] = self.session_token
         else:
            creds = (self.username, self.password)

      # Mask passwords in debug msgs
      display_body = body
      if display_body is not None and get_dbg_volume_level() >= dbg_msg_lvl:
         password_key = "Password"
         if password_key in display_body:
            display_body = body.copy()
            password_len = len(display_body[password_key])
            display_body[password_key] = "*" * password_len

      if method == "GET":
         qp = ""
         if query_parms is not None:
            qp = " (Query Parms: %s)" % query_parms
         dbg("GETting URI: %s%s" % (uri, qp), level=dbg_msg_lvl)
         resp = requests.get(uri, params=query_parms, verify=self.verify, auth=creds, headers=hdrs)

      elif method == "POST":
         dbg("POSTing to URI: %s" % uri, level=dbg_msg_lvl)
         if body is not None:
            dbg("...with JSON body:\n%s" % json_dumps(display_body), level=dbg_msg_lvl)
         resp = requests.post(uri, json=body, verify=self.verify, auth=creds, headers=hdrs)

      elif method == "PATCH":
         dbg("PATCHing URI: %s" % uri, level=dbg_msg_lvl)
         if body is not None:
            dbg("...with JSON body:\n%s" % json_dumps(display_body), level=dbg_msg_lvl)
         resp = requests.patch(uri, json=body, verify=self.verify, auth=creds, headers=hdrs)

      elif method == "DELETE":
         dbg("DELETing URI: %s" % uri, level=dbg_msg_lvl)
         resp = requests.delete(uri, verify=self.verify, auth=creds, headers=hdrs)

      # Only a few requests (eg. authenticating via session-auth, creating things) care about
      # the response headers, so we return just the response body as our return value.
      # But for those that need thems, we stash the entire response in self.last_response
      # for code to do as it pleases.  This approach would not work if we supported multiple
      # concurrent requests on a connection, but it seems unlikely we'll want to do that
      # (and not clear how, even if we wanted, given HTTP request/response orientation).

      self.last_response = resp
      return (self._check_for_error(resp))

   def do_get(self, resource_path, unauth=False, query_parms=None):
      resp = self.redfish_request("GET", resource_path, query_parms=query_parms, unauth=unauth)
      return _resp_json(resp)

   def do_post(self, resource_path, body=None, unauth=False):
      return _resp_json(self.redfish_request("POST", resource_path, body=body, unauth=unauth))

   def do_patch(self, resource_path, body=None):
      return _resp_json(self.redfish_request("PATCH", resource_path, body=body))

   def do_delete(self, resource_path, query_parms=None):
      resp = self.redfish_request("DELETE", resource_path, query_parms=query_parms)
      return _resp_json(resp)

   # Cache management.

   def _cache_resource(self, resource):

      key = resource["@odata.id"]
      self._cache_resource_at_key(key, resource)

   def _cache_resource_at_key(self, key, resource):

      dbg_msg_lvl = 8
      dbg_msg_lvl_verbose = 9

      msg_start = "Added to" if key not in self.resources else "Updated in"
      dbg("%s resource cache: %s" % (msg_start, key), level=dbg_msg_lvl)
      dbg("Resource contents: \n %s" % json_dumps(resource), level=dbg_msg_lvl_verbose)
      self.resources[key] = (now(), resource)

   def _uncache_resource(self, key):

      dbg_msg_lvl = 8
      dbg_msg_lvl_verbose = 9

      try:
         del self.resources[key]
         dbg("Removed from resource cache: %s" % key, level=dbg_msg_lvl)
      except KeyError:
         pass

   # Resource CRUD.

   def _get_resource(self, res_id, cacheable=True):

      dbg_msg_lvl = 8

      if cacheable and res_id in self.resources:
         dbg("Getting resource from cache: %s" % res_id, level=dbg_msg_lvl)
         return self.resources[res_id][1]

      res = self.do_get(res_id)
      if cacheable:
         self._cache_resource(res)
      else:
         # Don't leave a potentially stale copy cached.
         self._uncache_resource(res_id)

      return res

   def _update_resource(self, res_id, update_body):

      res = self.do_patch(res_id, update_body)

      # We could be fancier and merge the updates into the resource, but there
      # isn't currently a good use case that justifies the fanciness.  So instead
      # we just make sure we're not caching now-stale stuff.
      self._uncache_resource(res_id)

      return res

   def get_resource(self, res_id, cacheable=True):
      """
      Returns a reference identified by its id/path.  Will used cached value if permissted.
      """
      dbg("Getting resource %s" % res_id, level=self.dbg_msg_lvl_api_summary)
      return self._get_resource(res_id, cacheable=cacheable)

   # Task (Action/Job) management.

   def _start_task(self, task_start_path, task_body):

      resp_body = self.do_post(task_start_path, task_body)
      resp_hdrs = self.last_response.headers

      task_id = resp_hdrs["Location"]
      return task_id

   def _get_task(self, task_id):
      return self._get_resource(task_id, cacheable=False)

   def start_task(self, task_start_path, task_body):
      dbg("Starting task %s." % task_start_path, level=self.dbg_msg_lvl_api_summary)
      task_id = self._start_task(task_start_path, task_body)
      dbg("Queued/in-progress task id: %s" % task_id)
      return task_id

   def get_task(self, task_id):
      return self._get_task(task_id)

   # Collection CRUD.

   def _get_collection(self, coll_id, expand=0):
      # Note: We don't cache the collection resource because we're not going to
      # track any additions or removals from it, at least not yet.
      query_parm = None
      if expand != 0:
         query_parm = {"$expand": ".($levels=%d)" % expand}
      coll = self.do_get(coll_id, query_parms=query_parm)
      return coll

   def _get_collection_member_ids(self, coll_id):
      coll = self._get_collection(coll_id)

      try:
         members = coll["Members"]
      except KeyError:
         raise BMCRequestError(self, msg="Not a collection: %s" % key)

      return [m["@odata.id"] for m in members]

   def _get_collection_members(self, coll_id):
      member_ids = self._get_collection_member_ids(coll_id)
      return [self._get_resource(res_id) for res_id in member_ids]

   def get_collection_member_ids(self, coll_id):
      """
      Returns a list of  resource ids of  the members of the specified collection.
      """
      dbg("Getting ids of members of collection %s" % coll_id, level=self.dbg_msg_lvl_api_summary)
      member_ids = self._get_collection_member_ids(coll_id)
      cnt = len(member_ids)
      dbg("Returning ids of the %d resources in collection %s" % (cnt, coll_id), level=self.dbg_msg_lvl_api_summary)
      return member_ids

   def get_collection_members(self, coll_id):
      """
      Returns a list of resources that are the members of the specified collection.
      """
      dbg("Getting members of collection %s" % coll_id, level=self.dbg_msg_lvl_api_summary)
      member_resources = self._get_collection_members(coll_id)
      cnt = len(member_resources)
      dbg("Returning the %d resources in collection %s" % (cnt, coll_id), level=self.dbg_msg_lvl_api_summary)
      return member_resources


   def get_collection_member_with_name(self, coll_id, names):
      """
      Returns the first collection member that has the specified name.
      """

      check_names = names if type(names) is list else [names]

      member_ids = self._get_collection_member_ids(coll_id)
      for m_id in member_ids:
         m_res = self._get_resource(m_id)
         if m_res["Name"] in check_names:
            return m_res

      msg = "Member with name \"%s\" not found in collection %s."
      raise BMCRequestError(self, msg=msg % (str(names), coll_id))

   # Provide ids/instances of some key collections/resources.

   def _get_sys_collection_path(self):
      # Probably: /redfish/v1/Systems/
      return self.svc_root_res["Systems"]["@odata.id"]

   def _get_mgr_collection_path(self):
      # Probably: /redfish/v1/Managers
      return self.svc_root_res["Managers"]["@odata.id"]

   def _get_session_svc_path(self):
      # Probably: /redfish/va/SessionService
      return self.svc_root_res["SessionService"]["@odata.id"]

   def _get_session_collection_path(self):

      # Probably: /redfish/v1/SessionService/Sessions

      # Info on RedFish is inconsistent on how to best get the id of the Session collection.
      # Some web references suggest there is a SessionCollection entry in the service root
      # resource, but at least on iDRAC 9 there is none.  There is a Links/Sessions reference
      # though.  Other info suggests that as of RedFish 1.6, the Session collection's id
      # is always /redfish/v1/SessionsService/Sessions.

      # Web post show the Sesion collection id is also a property of the SessionService resource
      # (makes sense) but at least in Dell iDRAC 9, you can't do a get of the SessionService
      # resource when unauthenticated.

      # We'll sort of blend all of the above info into a stragey of assuing the session collect
      # is identifyed as <session_service_id>/Sessions.

      return self._get_session_svc_path() + "/Sessions"

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

      # Since the Redfish service we're connected to is that provided by a BMC (vs. a
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

   def get_this_system_resource(self, cacheable=True):
      res_path = self._get_this_system_id()
      return self._get_resource(res_path, cacheable=cacheable)

   # Account management.

   def _get_accounts(self, want_user_name=None, find_empty_slot=False):

      # This internal function is a hybrid thing that returns either a dict of  account
      # resources ndexed by name or a single account resource depending on  parameters:
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
      # Yep, this is a strange (maybe gross) combination of functions and maybe makes this
      # confusing and hard to maintain.  Blame this on perhaps an ill-advised attempt to have
      # common code.
      #
      # Notes:
      #
      # - It seems (at least on Dell), that the Accounts collection always has a fixed number
      #   of slots (ids 1 to 16), with them being empty (UserName is an empty string) or in-use
      #   for an  account (UserName not an empty string).  Further, it appears the entry at
      #   id 1 is not used (at least not in the Web UI).
      #
      #   To avoid looking through all 16 entries every time, we assume that the slots will be
      #   used in order, i.e. no empty ones between in-use ones, and thus consider we've hit
      #   the last defined account when we encounter an empty slot.

      quit_when_empty_slot_found=False

      used_as_internal_util= want_user_name is not None or find_empty_slot
      dbg_msg_lvl         = 5 if used_as_internal_util else 1
      dbg_msg_lvl_verbose = 5 if used_as_internal_util else 3

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
            dbg("Account details:\n%s" % json_dumps(acct_res), level=dbg_msg_lvl_verbose)
            accounts[user_name] = acct_res
            if user_name == want_user_name:
               # We found the user that was really wanted. Return just it.
               dbg("Found account for the user we were interested in.", level=dbg_msg_lvl)
               return acct_res
            #
         else:
            id = int(acct_res["Id"])
            if id > 1:
               if empty_slot is None:
                  # We found an empty slot.  Save it.
                  dbg("Found first empty account slot at id %d." % id, level=dbg_msg_lvl)
                  empty_slot = acct_res
               if quit_when_empty_slot_found:
                  break
            #
         #
      #

      if not used_as_internal_util:
         return accounts

      if find_empty_slot:
         return empty_slot
      else:
         return None

   def get_all_accounts(self):
      return self._get_accounts()

   def get_account(self, user_name):

      dbg("Getting BMC account for user \"%s\"" % user_name, level=1)
      acct_res = self._get_accounts(want_user_name=user_name)
      if acct_res is not None:
         dbg("%s" % json_dumps(acct_res), level=3)
         return acct_res
      else:
         dbg("BMC account for user \"%s\" not found." % user_name, level=1)
         return None

   def _map_role(self, role):

      role_mapping = {
         "administrator": "Administrator",
         "operator":      "Operator",
         "readonly":      "ReadOnly",
         "none":          "None"
      }
      mapped_role = role_mapping.get(role)
      if mapped_role is None:
         raise BMCRequestError(self, msg="Account role \"%s\" not recognized." % role)

      return mapped_role

   def create_account(self, user_name, password, role=None):
      ''''
      Creates the specified BMC account (user) with the specificed role.
      '''

      role = "none" if role is None else role
      dbg("Creating BMC account for user \"%s\" as role %s." % (user_name, role), level=1)

      # Look through accounts to find an available slot, and at the same time
      # verify the user doesn't already exist.  THis returns either an empty account
      # resource or the resource for the user we were asked to add.

      acct_res = self._get_accounts(want_user_name=user_name, find_empty_slot=True)

      # If we get None back, it means the account didn't already exist (good), but
      # we also have no empty slot to add a new one.

      if acct_res is None:
         raise BMCRequestError(self, msg="No room available for new account \"%s\"." % user_name)

      res_user_name = acct_res["UserName"]
      if res_user_name == user_name:
         raise BMCRequestError(self, msg="Account \"%s\" already exists." % user_name)

      dbg("Will create new account using slot at id %s" % acct_res["Id"], level=2)

      res_id = _get_resource_id(acct_res)

      update_body = dict()

      update_body["UserName"] = user_name
      update_body["Password"] = password
      update_body["Enabled"]  = True
      update_body["RoleId"]   = self._map_role(role)

      self._update_resource(res_id, update_body)

   def delete_account(self, user_name):
      ''''
      Deletes the specied  BMC account (user).
      '''

      if user_name == "root":
         raise BMCRequestError(self, msg="Refusing to delete account \"%s\" via automation." % user_name)

      dbg("Deleting BMC account for user \"%s\".", level=1)

      acct_res = self.get_account(user_name)
      if acct_res is None:
         raise BMCRequestError(self, msg="Account \"%s\" doesn't exist." % user_name)

      res_id = _get_resource_id(acct_res)
      update_body = dict()

      # On Dell iDRAC 9, you need to do the "delete" by first disabling the account and
      # then nulling-out the username, and you can't also null-out the password  Othwise,
      # it complains with a Status 400 ("The specified value is not allowed to be configured
      # if the user name or  password is blank.").

      update_body["Enabled"]  = False
      update_body["RoleId"]   = "None"
      self._update_resource(res_id, update_body)

      update_body.clear()
      update_body["UserName"] = ""
      # update_body["Password"] = ""
      self._update_resource(res_id, update_body)

   def set_account_role(self, user_name, role=None):
      ''''
      Sets the role for the specified BMC account (user).
      '''

      role = "none" if role is None else role
      dbg("Setting BMC account for user \"%s\" to have role %s." % (user_name, role), level=1)

      res_id = _get_resource_id(acct_res)
      update_body = dict()
      update_body["RoleId"] = self._map_role(role)

      self._update_resource(res_id, update_body)

   def set_account_password(self, user_name, password):
      ''''
      Set the password for the specified BMC account (user).
      '''

      dbg("Setting BMC account password for user \"%s\".", level=1)

      acct_res = self.get_account(user_name)
      if acct_res is None:
         raise BMCRequestError(self, msg="Account \"%s\" doesn't exist." % user_name)

      res_id = _get_resource_id(acct_res)
      update_body = dict()
      update_body["Password"] = password

      self._update_resource(res_id, update_body)

   # Server power-state/reset management.

   def get_power_state(self):
      ''''
      Get power state from the Computer System resource for this system/BMC.
      '''

      res = self.get_this_system_resource(cacheable=False)
      return res["PowerState"]

   def _do_system_reset_action(self, action_type):

      # GEt the URI path for the ComputerSystem.Reset action.

      res = self.get_this_system_resource(cacheable=False)
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
      dbg("Action Path: %s" % action_path, level=3)

      post_body = {"ResetType": action_type}
      resp_body = self.do_post(action_path, post_body)
      # Note: Despite being an Action, it appears the reset actions are always synchronous,
      # at least for Dell iDRAC.  Response status code is always 204 with no Location header.

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


class LabBMCConnection(object):

   # Notes:
   #
   # - This class contains an instance of a (Dell) BMC Connection object rather than
   #   being a subclasses of it in case we have non-Dell hardware in the future and
   #   we want this class to act as a fascade over all kinds.

   @staticmethod
   def add_bmc_login_argument_definitions(parser):

      parser.add_argument("--username", "-u",  dest="login_username")
      parser.add_argument("--password", "-p",  dest="login_password")
      parser.add_argument("--use-default-creds", "-D",  dest="use_default_creds", action="store_true")
      parser.add_argument("--as-admin", "-A",  dest="as_admin", action="store_true")
      parser.add_argument("--as-root",  "-R",  dest="as_root", action="store_true")
      parser.add_argument("--as-mgmt",  "-M",  dest="as_mgmt", action="store_true")

   @staticmethod
   def create_connection(machine_name, args, default_to_admin=False):

      username = args.login_username
      password = args.login_password
      for_std_user = None
      if args.use_default_creds:
         for_std_user = "default"
      elif args.as_root:
         for_std_user = "root"
      elif args.as_mgmt:
         for_std_user = "mgmt"
      elif args.as_admin or default_to_admin:
         for_std_user = "admin"

      if username is not None:
         dbg("Creating connection to %s as specified user\" %s\"." % (machine_name, username), level=1)
      elif for_std_user is not None:
         dbg("Creating connection to %s as standard user \"%s\"." % (machine_name, for_std_user), level=1)
      else:
         dbg("Creating connection to %s using default standard user." % machine_name, level=1)

      return LabBMCConnection(machine_name, username=username, password=password,
                              for_std_user=for_std_user)

   def __init__(self, machine_name, username=None, password=None, for_std_user=None):

      if (username is not None) != (password is not None):
         die("Both BMC login username and password are required if either is provided.")

      self.machine_info = None
      bmc_cfg = self._get_bmc_cfg(machine_name, for_std_user=for_std_user)

      self.host = bmc_cfg["address"]
      self.username = bmc_cfg["username"] if username is None else username
      self.password = bmc_cfg["password"] if password is None else password
      # Future: Maybe also accept username/password from env vars?

      self.connection = DellBMCConnection(self.host, self.username, self.password)

      # Because we're doing things by composition of rahter than subclassing from the
      # BMCConnection class, we have to explicitly "export" the methods of the
      # BMCConnection classs that we want to be part of our API.

      self.get_resource           = self.connection.get_resource
      self.get_collection_members = self.connection.get_collection_members
      self.get_system_resource    = self.connection.get_this_system_resource
      self.get_collection_member_ids       = self.connection.get_collection_member_ids
      self.get_collection_member_with_name = self.connection.get_collection_member_with_name

      self.start_task       = self.connection.start_task
      self.get_task         = self.connection.get_task

      self.get_power_state         = self.connection.get_power_state
      self.get_system_power_state  = self.connection.get_power_state
      self.system_power_on         = self.connection.system_power_on
      self.system_power_off        = self.connection.system_power_off

      self.get_all_accounts     = self.connection.get_all_accounts
      self.get_account          = self.connection.get_account
      self.create_account       = self.connection.create_account
      self.delete_account       = self.connection.delete_account
      self.set_account_password = self.connection.set_account_password

   def _get_bmc_cfg(self, machine_name, for_std_user=None):

      m_entry = None
      bmc_cfg = {}
      try:
         m_entry = get_machine_entry(machine_name, for_std_user=for_std_user)
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

