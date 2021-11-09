#!/bin/python3

# Creates a n BMC account (user).

# Author: J. M. Gdaniec, Apr 2021

from lab_common import *

import argparse
import traceback

def main():

   # set_dbg_volume_level(6)

   role_choices = ["administrator", "operator", "readonly", "none"]

   parser = argparse.ArgumentParser()
   parser.add_argument("machine" )
   parser.add_argument("username")
   parser.add_argument("password")
   parser.add_argument("role", choices=role_choices)

   LabBMCConnection.add_bmc_login_argument_definitions(parser)

   args = parser.parse_args()

   machine   = args.machine
   acct_name = args.username
   acct_pw   = args.password
   acct_role = args.role

   bmc_conn = LabBMCConnection.create_connection(machine, args, default_to_admin=True,
                                                 use_default_bmc_info=True)

   bmc_conn.create_account(acct_name, acct_pw, role=acct_role)

if __name__ == "__main__":
   try:
      main()
   except BMCRequestError as exc:
      die(str(exc))
   except Exception:
      traceback.print_exc()
      die("Unhandled exception!")

