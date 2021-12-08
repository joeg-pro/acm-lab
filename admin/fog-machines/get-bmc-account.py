#!/bin/python3

# Deletes a n BMC account (user).

# Author: J. M. Gdaniec, Apr 2021

from bmc_common import *

import argparse
import traceback

def main():

   # set_dbg_volume_level(6)

   parser = argparse.ArgumentParser()
   parser.add_argument("machine" )
   parser.add_argument("username")

   LabBMCConnection.add_bmc_login_argument_definitions(parser)

   args = parser.parse_args()

   machine   = args.machine
   acct_name = args.username

   bmc_conn = LabBMCConnection.create_connection(machine, args, default_to_admin=True)

   acct_res = bmc_conn.get_account(acct_name)
   print(json_dumps(acct_res))

if __name__ == "__main__":
   try:
      main()
   except BMCRequestError as exc:
      die(str(exc))
   except Exception:
      traceback.print_exc()
      die("Unhandled exception!")

