#!/bin/python3

# Sets the password for a BMC account (user).

# Author: J. M. Gdaniec, Apr 2021

from lab_common import *

import argparse
import traceback

def main():

   # set_dbg_volume_level(6)

   parser = argparse.ArgumentParser()
   parser.add_argument("machine" )
   parser.add_argument("username")
   parser.add_argument("password")

   LabBMCConnection.add_bmc_login_argument_definitions(parser)

   args = parser.parse_args()

   machine   = args.machine
   acct_name = args.username
   acct_pw   = args.password

   bmc_conn = LabBMCConnection.create_connection(machine, args, default_to_admin=True)

   bmc_conn.set_account_password(acct_name, acct_pw)

if __name__ == "__main__":
   try:
      main()
   except BMCRequestError as exc:
      die(str(exc))
   except Exception:
      traceback.print_exc()
      die("Unhandled exception!")

