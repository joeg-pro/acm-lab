
# Some common functions for ACM Lab Fog-machine stuff.

# Assumes: Python 3.6+

import json
import os
import sys
import yaml

from threading import Thread, Lock, Event

from misc_utils import *
from bmc_common import *

db_loading_lock = Lock()

# --- Lab-tailored BMC Classes ---

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
   def create_connection(machine_name, args, default_to_admin=False, default_to_default=False,
                                             use_default_bmc_info=False):

      username = args.login_username
      password = args.login_password
      for_std_user = None
      if args.use_default_creds:
         for_std_user = "default"
      elif args.as_root:
         for_std_user = "root"
      elif args.as_mgmt:
         for_std_user = "mgmt"
      elif args.as_admin:
         for_std_user = "admin"
      else:
         if default_to_admin:
            for_std_user = "admin"
         elif default_to_default:
            for_std_user = "default"
         else:
            # Allow env var to override creds used for general tools that
            # don't already specify a particular set of creds.
            if os.getenv("ACM_LAB_USE_BMC_ADMIN_CREDS"):
               for_std_user = "admin"

      if use_default_bmc_info and for_std_user is None:
         for_std_user = "default"

      if username is not None:
         dbg("Creating connection to %s as specified user\" %s\"." % (machine_name, username), level=3)
      elif for_std_user is not None:
         dbg("Creating connection to %s as standard user \"%s\"." % (machine_name, for_std_user), level=3)
      else:
         dbg("Creating connection to %s using default standard user." % machine_name, level=3)

      return LabBMCConnection(machine_name, username=username, password=password,
                              for_std_user=for_std_user, use_default_bmc_info=use_default_bmc_info)

   def __init__(self, machine_name, username=None, password=None,
                for_std_user=None, use_default_bmc_info=False):

      if (username is not None) != (password is not None):
         die("Both BMC login username and password are required if either is provided.")

      self.machine_info = None
      bmc_cfg = self._get_bmc_cfg(machine_name, for_std_user=for_std_user,
                                  use_default_bmc_info=use_default_bmc_info)

      self.host = bmc_cfg["address"]
      self.username = bmc_cfg["username"] if username is None else username
      self.password = bmc_cfg["password"] if password is None else password
      # Future: Maybe also accept username/password from env vars?

      self.connection = DellBMCConnection(self.host, self.username, self.password)

      # Because we're doing things by composition of rahter than subclassing from the
      # BMCConnection class, we have to explicitly "export" the methods of the
      # BMCConnection classs that we want to be part of our API.

      self.get_resource           = self.connection.get_resource
      self.get_collection         = self.connection.get_collection
      self.get_collection_members = self.connection.get_collection_members
      self.get_collection_member_ids       = self.connection.get_collection_member_ids
      self.get_collection_member_with_name = self.connection.get_collection_member_with_name

      self.get_service_root_resource   = self.connection.get_service_root_resource
      self.get_system_resource         = self.connection.get_this_system_resource
      self.get_system_manager_resource = self.connection.get_this_system_manager_resource

      self.update_resource       = self.connection.update_resource
      self.update_resource_by_id = self.connection.update_resource_by_id

      self.start_task     = self.connection.start_task
      self.get_task       = self.connection.get_task
      self.perform_action = self.connection.perform_action

      self.get_power_state         = self.connection.get_power_state
      self.get_system_power_state  = self.connection.get_power_state
      self.system_power_on         = self.connection.system_power_on
      self.system_power_off        = self.connection.system_power_off
      self.system_reboot           = self.connection.system_reboot
      self.system_shutdown         = self.connection.system_shutdown

      self.get_all_accounts     = self.connection.get_all_accounts
      self.get_account          = self.connection.get_account
      self.create_account       = self.connection.create_account
      self.delete_account       = self.connection.delete_account
      self.set_account_password = self.connection.set_account_password

   def _get_bmc_cfg(self, machine_name, for_std_user=None, use_default_bmc_info=False):

      m_entry = None
      bmc_cfg = {}
      try:
         m_entry = get_machine_entry(machine_name, for_std_user=for_std_user,
                                     use_default_bmc_info=use_default_bmc_info)
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


# --- Getting info from our lab machine-info database (yaml file) ---

machine_info = None

def _load_machine_info_db_inner(for_std_user=None):

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

def _load_machine_info_db(for_std_user=None):

   # Wrap db-loading with a lock to make this thread safe.

   global machine_info
   with db_loading_lock:
      if machine_info is not None:
         return
      _load_machine_info_db_inner(for_std_user)

def get_machine_entry(machine_name, for_std_user=None, use_default_bmc_info=False):

   _load_machine_info_db(for_std_user=for_std_user)

   # Although the machine name key in the database isn't a hostname, we often
   # use it as the first component of a dotted fully-squalified hostname.
   # As a conveninece, accept it that form and use the first component as
   # the machine name.

   machine_name,junk = split_at(machine_name, ".", favor_right=False)

   try:
      return machine_info[machine_name]
   except KeyError:
      if use_default_bmc_info:
         info = machine_info["default"]
         # The address and redfish entries are expected to contain a single %s
         # substitution placeholder that we replace with the machine name.
         info["bmc"]["address"] = info["bmc"]["address"] % machine_name
         info["bmc"]["redfish"] = info["bmc"]["redfish"] % machine_name
         return info
      else:
         die("Machine %s not recored in machine info db." % machine_name)
   #
#


# -- Iterating across a bunch of machines to do the same thing ---

def adjust_task_resource(task_res):

   # If the resource provided isn't a DMTF-compatible Task resource, try
   # to convert the vendor-specific thing provide to such a thing. Changes
   # are done in place.
   #
   # Currnetly only attempts to map a Dell Job-type task, and does so only based
   # on observation to determine the mapping.  So this is fragile/incomplete.

   if "TaskState" in task_res:
      return  # Looks like a DMTF Task resource.

   res_type = task_res["@odata.type"]
   if not res_type.startswith("#DellJob."):
      return # We don't recognize the resource.  Nothing we can do.

   job_state = task_res["JobState"]
   try:
      msg = task_res["Message"]
   except KeyError:
      msg = "No message"
   try:
      msg_id = task_res["MessageId"]
   except KeyError:
      msg_id = "NO-MSGID"

   if job_state == "Scheduled":
      task_res["TaskState"] = "Pending"

   elif job_state == "Running":
      task_res["TaskState"] = "Running"

   elif job_state == "Completed":

      # It seems the only way to tell success vs. other endings is by looking at
      # message/message id.  To be conservatine and not mask failures, we will assume
      # the job ended with errors if we can't match up the job-id against the
      # (seemingly open-ended) list of success messages.

      task_res["TaskState"] = "Exception"
      task_res["TaskStatus"] = "Critical"

      if msg_id in ["RED001", "JCP007", "PR19"]:
         # "Job completed successfully.", "Job successfully completed."
         task_res["TaskState"]  = "Completed"
         task_res["TaskStatus"] = "OK"
   else:
      task_res["TaskState"] = "Not-Recognized"
      dbg("Don't know how to map Dell job at this state:\n%s" % json_dumps(task_res))


# Task orchestrator that runs running a given task/job across a set of machines.
# Task particulars are specified via a passed task-customization class.  Runs the steps
# in phases/passes across the machine, optionally doing things in parallel via threading.
#
# Terminology:
#
# - Task   = The class/object that describes what is to be done in each pass.
#
# - Thread = A Python Threading object that executes a task method/methods (for a
#            particular machine) in parallel with other machines.

# These _TR_ classes are thread classes to premit multi-threading.

class _TR_ConnectAndValidate(Thread):

    def __init__(self, machine, connection_args, the_task_class,
                       task_arg=None, default_to_admin=False):
       Thread.__init__(self)
       self.machine = machine
       self.connection_args = connection_args
       self.the_task_class = the_task_class
       self.task_arg = task_arg
       self.default_to_admin = default_to_admin

    def run(self):

       machine = self.machine

       blurt("Opening BMC connection and doing verification.", prefix=machine)
       bmc_conn = LabBMCConnection.create_connection(machine, self.connection_args,
                                                     default_to_admin= self.default_to_admin)

       self._task = self.the_task_class(machine, bmc_conn, self.task_arg)
       self._pre_check_ok = self._task.pre_check()

    def task(self):
       return self._task

    def pre_check_ok(self):
       return self._pre_check_ok

#

class _TR_PrepareTaskRequest(Thread):

    def __init__(self, task, announce_actions):
       Thread.__init__(self)
       self._task   = task
       self.machine = task.get_machine()

    def run(self):
       self._task_is_needed = self._task.prepare_task_request()
       if not self._task_is_needed:
          blurt("No task is necessary.", prefix=self.machine)

    def task(self):
       return self._task

    def task_is_needed(self):
       return self._task_is_needed

class _TR_RunTask(Thread):

   def __init__(self, task, announce_actions):
      Thread.__init__(self)
      self._task   = task
      self.machine = task.get_machine()
      self.announce_actions = announce_actions

      self._task_has_ended = False

      self._testing = False
      self.dummy_task_id       = "DUMMY-TASK-ID"
      self.dummy_task_check_nr = 0

   def task(self):
      return self._task

   def ok(self):
      return self._ok

   def _set_ok(self, is_ok):
      self._ok = is_ok

   def task_has_ended(self):
      return self._task_has_ended

   # Run() is called when we are running the task in a multhreading-enabled way.  It runs
   # all of the phases for a given machine, using the various do_*() methods to do si.
   # The do_*() methods are called individually from external (to this class) orchestration
   # logic when we're not operatoring in a multithreading mode.
   #
   # Its a shame that there is some duplication betweeh what run() does and what the
   # non-multithreading orchestration does, but the present author hasn't figured out a
   # better way to handle this (yet).

   def run(self):

      machine = self.machine
      task    = self._task

      sleeper = Event()

      idrac_pause_time        = 15 if not self._testing else 2
      check_status_pause_time = 15 if not self._testing else 2

      # Run the pre-submit phase, pausing afterwards if requeted.

      pause = self.do_pre_submit()
      if not self._ok:
         return
      if pause:
         blurt("Pausing a bit to allow iDRAC to catch up.", prefix=machine)
         sleeper.wait(idrac_pause_time) # Really gross

      # Run the submit phase.

      self.do_submit()
      if not self._ok:
         return
      blurt("Pausing a bit to allow iDRAC to catch up.", prefix=machine)
      sleeper.wait(idrac_pause_time)  # Really gross.

      # Run the post-submit phase.

      pause = self.do_post_submit()
      if not self._ok:
         return
      if pause:
         blurt("Pausing a bit to allow iDRAC to catch up.", prefix=machine)
         sleeper.wait(idrac_pause_time) # Really gross

      # Check on status periodically until task is done.

      has_ended = False
      while not has_ended:
         has_ended = self.check_task_status()
         if not has_ended:
            sleeper.wait(check_status_pause_time)
      if not self.ok():
         return

      # Report on completion.

      self.report_on_completion()
      if not self.ok():
         return

      # Run the post-completion phase.

      self.do_post_completion()

      # All done for this machine/task/thread.

   def _do_pre_or_post_phase(self, phase_name, announce_method, phase_method):

      task    = self._task
      machine = self.machine

      self._set_ok(True)

      try:
         if self.announce_actions:
            announce_method(machine=machine)
         if not self._testing:
            return phase_method()
         else:
            blurt("TESTING: No-op'ing %s call." % phase_name, prefix=machine)
            return True
      except BMCError as exc:
         emsg(str(exc))
         blurt("Abandoning futher action due to preceeding errors.", prefix=machine)
         self._set_ok(False)
         return False

   def do_pre_submit(self):

      # Perform pre-submit pass, intnedned to get the machine into whatever
      # pre-task-submit state is required if more than power control is needed.

      task = self._task
      return self._do_pre_or_post_phase("pre-submit", task.announce_pre_submit_pass, task.pre_submit)

   def do_submit(self):

      # Submit the BMC task request.

      task    = self._task
      machine = self.machine

      bmc_conn        = task.get_bmc_conn()

      self._set_ok(False)

      try:
         task_target = task.get_task_target()
         task_body   = task.get_task_body()

         if task_target is None:
            reason = "No task target set"
            blurt("Abaonding further action: %s." % reason, prefix=machine)
            self._set_ok(False)
         else:
            if self.announce_actions:
               short_task_name = task.get_short_task_name()
               blurt("Submitting %s task." % short_task_name, prefix=machine)
            if not self._testing:
               task_id = bmc_conn.start_task(task_target, task_body)
            else:
               blurt("TESTING: No-op'ing BMC task submission.", prefix=machine)
               task_id = self.dummy_task_id
            dbg("Task id: %s" % task_id, level=3)
            task.set_task_id(task_id)
            self._set_ok(True)

      except BMCRequestError as exc:
         emsg("Request error: %s" % exc, prefix=machine)
         reason = "Could not submit %s task" % short_task_name
         blurt("Abaonding further action: %s." % reason, prefix=machine)
         self._set_ok(False)

   def do_post_submit(self):

      # Perform post-submit pass, intnedned to niudge the machine in whatever
      # way needed to get it to run the pending tasks, for example powering them on.

      task = self._task
      return self._do_pre_or_post_phase("post-submit", task.announce_post_submit_pass, task.post_submit)

   # For Testing: Returns a dummy BMC Task resource, sufficient for the
   #  completion/status checking we do.

   def _mfg_bmc_task_res(self):

      self.dummy_task_check_nr += 1

      if self.dummy_task_check_nr == 1:
         task_state = "Pending"
         task_status = "N/A"
         pct_complete = 0
      elif self.dummy_task_check_nr == 2:
         task_state = "Starting"
         task_status = "N/A"
         pct_complete = 0
      elif self.dummy_task_check_nr == 3:
         task_state = "Running"
         task_status = "N/A"
         pct_complete = 33
      elif self.dummy_task_check_nr == 4:
         task_state = "Running"
         task_status = "N/A"
         pct_complete = 66
      elif self.dummy_task_check_nr == 5:
         task_state = "Completed"
         task_status = "OK"
         pct_complete = 100

      bmc_task_res = {
         "TaskState":       task_state,
         "TaskStatus" :     task_status,
         "PercentComplete": pct_complete
      }

      return bmc_task_res

   def check_task_status(self):

      if self._task_has_ended:
         return self._task_has_ended

      task    = self._task
      machine = self.machine

      bmc_conn = task.get_bmc_conn()
      task_id  = task.get_task_id()

      self._set_ok(True)

      try:
         if task_id != self.dummy_task_id:
            bmc_task_res = bmc_conn.get_task(task_id)
         else:
            bmc_task_res = self._mfg_bmc_task_res()
         adjust_task_resource(bmc_task_res)
         if task_has_ended(bmc_task_res):
            blurt("Task has ended.", prefix=task.machine)
            self._task_has_ended = True
            task.ending_task_res = bmc_task_res ## Should use a setter ##
         else:
            bmc_task_state = bmc_task_res["TaskState"]

            if bmc_task_state == "":
               # Dell iDRAC seems to sometimes provide no task state, for example
               # when running Import-Configuration jobs (MessageId IDRAC.2.4.SYS034).
               # Use the job state from the Dell Oem info in these cases if we can
               # find same.
               try:
                  bmc_task_state = "%s*" % bmc_task_res["Oem"]["Dell"]["JobState"]
               except KeyError:
                  bmc_task_state = "???"

            if bmc_task_state == "Pending":
               blurt("Task is scheduled/pending.", prefix=machine)
            elif bmc_task_state == "Starting":
               # On Dell iDRAC, it seems tasks remaining in Starting while the system is
               # going through its power-on initialization.  Then the task transitions
               # to running when LC has control.
               blurt("Machine is still starting up.", prefix=machine)
            else:
               bmc_tasK_pct_complete = bmc_task_res["PercentComplete"]
               blurt("Task still in progress: %s (%d%% complete)." %
                     (bmc_task_state, bmc_tasK_pct_complete), prefix=machine)

      except BMCRequestError as exc:
         emsg("BMC request error: %s" % exc, prefix=machine)
         self._task_has_ended = True
         task.ending_task_res = None
         blurt("Abaonding further action: %s." % reason, prefix=machine)
         self._set_ok(False)

      return self._task_has_ended

   def report_on_completion(self):

      task    = self._task
      machine = self.machine

      bmc_task_res = task.ending_task_res
      if bmc_task_res is not None:
         bmc_task_status = bmc_task_res["TaskStatus"]
         bmc_task_state = bmc_task_res["TaskState"]
         if bmc_task_state == "Completed":
            short_task_name = task.get_short_task_name()
            blurt("Task %s has comopleted successfully." % short_task_name, prefix=machine)
         else:
            blurt("Task %s has failed.  Ending state/status: %s/%s" %
                  (short_task_name, bmc_task_state, bmc_task_status), prefix=machine)
      else:
         blurt("Task %s state is unknown due to previous errors." % short_task_name, prefix=machine)

   def do_post_completion(self):

      # Perform post-completion phase, intnedned to get the machine into whatever post-
      # completion state is desired, such as powering off again if the task needed to
      # leave the machine powered on.

      task = self._task
      return self._do_pre_or_post_phase("post-completion", task.announce_post_completion_pass, task.post_completion)


class TaskRunner:

   def __init__(self, machines, connection_args, the_task_class,
                task_arg=None, default_to_admin=False):

      self.machines         = machines
      self.connection_args  = connection_args
      self.the_task_class   = the_task_class
      self.task_arg         = task_arg
      self.default_to_admin = default_to_admin

      self.multi_threaded = the_task_class.is_multi_thread_safe()

      self._testing = False

      self.tasks = dict()

   # Run all of the run() methods of a collection of thread objects, either
   # seriall or on parallel threads if multi_threading is enabled.

   def _run_threads(self, threads):
      if self.multi_threaded:
         for machine in list(threads.keys()):
            threads[machine].start()
         for machine in list(threads.keys()):
            threads[machine].join()
      else:
         for machine in list(threads.keys()):
            threads[machine].run()
      return threads

   # Create thread objects for all of the specified tasks.

   def _create_threads_for_tasks(self, thread_class, tasks):
      threads = dict()
      for machine in list(tasks.keys()):
         threads[machine] = thread_class(tasks[machine], self.multi_threaded)
      return threads

   # Create thread objects for all of the specified tasks, running their run() methods
   # either serially or in paralle if multi-threading is enabled.

   def _create_and_run_threads_for_tasks(self, thread_class, tasks):
      threads = self._create_threads_for_tasks( thread_class, tasks)
      self._run_threads(threads)
      return threads

   @staticmethod
   def _absndon_failed_threads(threads):
      for machine in list(threads.keys()):
         if not threads[machine].ok():
            # Msg re abandonment already blurted as part of do_<something> processing.
            del threads[machine]

   @staticmethod
   def _reconsile_tasks_with_threads(tasks, threads):
      for machine in list(tasks.keys()):
         if machine not in threads:
            del tasks[machine]

   def _do_pass(self, threads, phase_name, announce_method, phase_method, idrac_pause_time=None):

      # Blurt out info on the pass we are about to run.
      announce_method()

      pause_after_pass = False
      for machine in list(threads.keys()):
         t = threads[machine]
         pause = phase_method(t)
         pause_after_pass = pause_after_pass or (pause and t.ok())

      # Abandon threads/tasks that didn't successfully perform pre-submit().
      self._absndon_failed_threads(threads)

      if idrac_pause_time and pause_after_pass and threads:
         blurt("Pausing a bit to allow the iDRACs to catch up.")
         time.sleep(idrac_pause_time)  # Really gross.

   def run(self):

      the_task_class = self.the_task_class

      idrac_pause_time        = 15 if not self._testing else 2
      check_status_pause_time = 15 if not self._testing else 2

      # Open BMC connections to each of the machines and do quick pre-checks.
      # If pre-checks fail for any machine, we abort the whole thing.

      threads = dict()
      for machine in self.machines:
         threads[machine] = _TR_ConnectAndValidate(machine, self.connection_args, self.the_task_class,
                                                   self.task_arg, default_to_admin=self.default_to_admin)
      #

      self._run_threads(threads)

      errors_occurred = False
      for machine in list(threads.keys()):
         t = threads[machine]
         if t.pre_check_ok():
            self.tasks[machine] = t.task()
         else:
            errors_occurred = True

      if errors_occurred:
         blurt("Aborting because one or more machines failed verification checks.")
         return

      # Give all the tasks a chance to prepare input, or decline to do so, before
      # we start any real work.

      threads = self._create_and_run_threads_for_tasks(_TR_PrepareTaskRequest, self.tasks)

      tasks_are_needed = False
      for machine in list(threads.keys()):
         t = threads[machine]
         if t.task_is_needed():
            tasks_are_needed = True
         else:
            del self.tasks[machine]
      #
      if not tasks_are_needed:
         blurt("No tasks are needed.")
         return

      threads = self._create_threads_for_tasks(_TR_RunTask, self.tasks)

      if self.multi_threaded:

         # Run the threads that perform all of the phases in sequence and exit
         #  when all phases are done or the task for the machine is abandoned
         # due to errors.

         self._run_threads(threads)

      else:

         # Not using threads, so we run the phases in passes across all
         # of the machines.

         the_tr_class = _TR_RunTask

         # Perform pre-submit pass across all machines.

         self._do_pass(threads, "pre-submit", the_task_class.announce_pre_submit_pass,
                       the_tr_class.do_pre_submit, idrac_pause_time)
         if not threads:
            blurt("No machines successfully estbalished pre-submit conditions.")
            return

         # Submit the task requests.

         short_task_name = self.the_task_class.get_short_task_name()
         blurt("Submitting %s task requests." % short_task_name)

         for machine in list(threads.keys()):
            threads[machine].do_submit()

         # Abandon threads/tasks that didn't successfully submit a BMC task.
         self._absndon_failed_threads(threads)
         if not threads:
            blurt("No %s tasks were started." % short_task_name)
            return

         blurt("Pausing a bit to allow the iDRACs to catch up.")
         time.sleep(idrac_pause_time)  # Really gross.

         # Perforom post-submit pass across all of the machines.

         self._do_pass(threads, "post-submit", the_task_class.announce_post_submit_pass,
                       the_tr_class.do_post_submit, idrac_pause_time)
         if not threads:
            blurt("No machines successfully estbalished post-submit conditions.")
            return

         print("Waiting for submmitted %s tasks to complete." % short_task_name)
         pending_tasks = {m:t for m, t in threads.items()}

         while pending_tasks:
            for machine in list(pending_tasks.keys()):
               t = pending_tasks[machine]
               t_has_ended = t.check_task_status()
               if t_has_ended:
                  del pending_tasks[machine]
            #
            if len(pending_tasks) > 0:
               time.sleep(check_status_pause_time)

         # Abandon threads/tasks that didn't get to end-of-task cleanly.
         self._absndon_failed_threads(threads)

         # All tasks have ended.  Report on completion.

         for machine in list(threads.keys()):
            t = threads[machine]
            t.report_on_completion()

         # Prtgotm yhr pody-completion pass across all of the machines.

         self._do_pass(threads, "post-completion", the_task_class.announce_post_completion_pass,
                       the_tr_class.do_post_completion)
      #

      blurt("Finished.")

# Base class for task classes that TaskRunner can run.

class RunnableTask:

   def __init__(self, machine, bmc_conn, task_arg=None):

      self.machine  = machine
      self.bmc_conn = bmc_conn

      self.task_target = None
      self.task_body   = None

   def get_machine(self):
      return self.machine

   def get_bmc_conn(self):
      return self.bmc_conn

   def set_task_id(self, task_id):
      self.task_id = task_id

   def get_task_id(self):
      return self.task_id

   def pre_check(self):
      return True

   def prepare_task_request(self):
      # Give task a chance to defer prep of task target or body until we need it.
      return True

   def get_task_target(self):
      return self.task_target

   def get_task_body(self):
      return self.task_body

   @classmethod
   def is_multi_thread_safe(self):
      # Override and return True if a concrete Task class is thread-safe, i.e. can
      # tolerate having actions for the machines run in parallel on multiple threads.
      return False

   @classmethod
   def announce_pre_submit_pass(self, machine=None):
      return

   def pre_submit(self):
      return False  # Didn't do anything, so no BMC-catch-up pausing needed.

   @classmethod
   def announce_post_submit_pass(self, machine=None):
      return

   def post_submit(self):
      return False  # Didn't do anothing, so no BMC-catch-up pausing needed.

   @classmethod
   def announce_post_completion_pass(self, machine=None):
      return

   def post_completion(self):
      return

   def do_power_action(self, desired_power_state):

      machine = self.machine
      bmc_conn = self.bmc_conn

      did_something = False
      try:
         current_power_state = bmc_conn.get_power_state()
         dbg("[%s] Machine power state: %s" % (machine, current_power_state), level=3)
         if current_power_state != desired_power_state:
            blurt("Powering machine %s." % desired_power_state, prefix=machine)
            if desired_power_state == "Off":
               bmc_conn.system_power_off()
            else:
               bmc_conn.system_power_on()
            did_something = True
         else:
            blurt("Machine was already Powered %s." % desired_power_state, prefix=machine)

      except BMCRequestError as exc:
         m = "Could not check/control power for machine  %s: %s" % (machine, exc)
         raise BMCError(m)

class DellSpecificTask(RunnableTask):

   def __init__(self, machine, bmc_conn, task_arg=None):
      super(DellSpecificTask, self).__init__(machine, bmc_conn, task_arg)

   def verify_vendor_is_dell(self):

      # Make sure we're managing a Dell server because our actions make
      # use of Dell-specific resources/actions.

      service_root_res = self.bmc_conn.get_service_root_resource()
      vendor = service_root_res["Vendor"]
      if vendor != "Dell":
         emsg("Machine %s is not a Dell server." % self.machine)
         return False
      return True

   def pre_check(self):
     return self.verify_vendor_is_dell()
#
