#!/bin/python3
# Some utility functions used acrosss some of the fog-*.py scripts.  These are likely
# Dell iDRAC specific, or worse yet, specific to the style of script writing by the
# present author.

from bmc_common import *

# -- Iterating across a bunch of machines to do the same thing ---

# The following functions facilitate doing the same thing across a set of machines in
# parallel.  While the ideas here could be generalized, these implementations are quite
# specific to the style of script writing for the current set of exploting scripts.
# (As Demi Lovoto has said, Sorry,not Sorry.)


# Run a specified function for a list of target machines, providing each invocation with
# the machine and a BMC connection for that machine along with other specified (always the
# same for each invocation) arguments.  Aggregates an overall bool result by a simple Or
# operation of the individual function invocations, on the assumption that the result(s)
# indicate whether something was done or the action was a no-op / failed.

def for_all_with_conn(targets, bmc_conns, func, *args, **kwargs):

   summarized_result = False

   for this_target in list(targets):
      bmc_conn = bmc_conns[this_target]
      r = func(this_target, bmc_conn, targets, *args, **kwargs)
      if type(r) == bool:
         summarized_result = summarized_result or r

   return summarized_result

# Do a power action (power on/off) as needed on a machine with some blabbing about
# what was done for log/following-along purposes.
#
# Can be used as a target function run via for_all_with_conn().

def power_action(machine, bmc_conn, machines, desired_power_state):

   # desired_power_state is either "Off" or "On".

   did_something = False
   try:
      current_power_state = bmc_conn.get_power_state()
      dbg("Server %s power state: %s" % (machine, current_power_state))
      if current_power_state != desired_power_state:
         print("   Powering %s %s." % (machine, desired_power_state))
         if desired_power_state == "Off":
            bmc_conn.system_power_off()
         else:
            bmc_conn.system_power_on()
         did_something = True
      else:
         print("   System %s was already Powered %s." % (machine, desired_power_state))

   except BMCRequestError as exc:
      emsg("Request error from %s: %s" % (machine, exc))
      reason = "Could not check/power-off system"
      blurt("Abaonding further action for %s: %s." % (machine, reason))
      del machines[machine]

   return did_something

# Submit a task (job to be run asynchronously) on a machine.  If submission fails,
# remove that machine from the machine list (so as to remove it from futher actions
# based on that list).
#
# Can be used as a target function run via for_all_with_conn().

def submit_task(machine, bmc_conn, machines, short_task_name, action_targets, options, task_ids):

   short_task_name = "virtual-disk-init"
   action_target = action_targets[machine]

   try:
      blurt("   Submitting %s task on %s." % (short_task_name, machine))

      task_id = bmc_conn.start_task(action_target, options)
      dbg("Task id: %s" % task_id)
      task_ids[machine] = task_id

   except BMCRequetError as exc:
      emsg("Request error from %s: %s" % (machine, exc))
      msg = "Could not submit %s task" % short_task_name
      blurt("Abaonding further action for %s: %s." % (machine, reason))
      del machines[machine]

   return

# Check on the status of last submitted task on a machine.
#
# Can be used as a target function run via for_all_with_conn().

def check_task_status(machine, bmc_conn, task_ids, ending_task_ress):

   dbg("Checking task status for system %s." % machine, level=2)

   task_id  = task_ids[machine]

   try:
      task_res = bmc_conn.get_task(task_id)
      if task_has_ended(task_res):
         blurt("Task for system %s has ended." % machine)
         del task_ids[machine]
         ending_task_ress[machine] = task_res
      else:
         task_state = task_res["TaskState"]
         if task_state == "Starting":
            # On Dell iDRAC, it seems tasks remaining in Starting while the
            # system is going through its power-on initialization.  Then the
            # task transitions to running when LC has control.
            blurt("System %s is still starting up." % machine)
         else:
            tasK_pct_complete = task_res["PercentComplete"]
            blurt("Task for system %s still in progress: %s (%d%% complete)." %
                  (machine, task_state, tasK_pct_complete))

   except BMCRequestError as exc:
      emsg("BMC request error from %s: %s" % (machine, exc))
      del task_ids[machine]
      ending_task_ress[machine] = None
