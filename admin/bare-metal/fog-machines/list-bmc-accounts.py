#!/bin/python3

# Lists all defined BMC accounts.

# Author: J. M. Gdaniec, Apr 2021

from lab_common import *

import argparse
import traceback

def main():

   # set_dbg_volume_level(1)

   parser = argparse.ArgumentParser()
   parser.add_argument("machine" )

   LabBMCConnection.add_bmc_login_argument_definitions(parser)

   args = parser.parse_args()

   machine   = args.machine

   bmc_conn =LabBMCConnection.create_connection(machine, args, default_to_admin=True,
                                                use_default_bmc_info=True)

   acct_collection = bmc_conn.get_all_accounts()
   for name, acct_res in acct_collection.items():
      # print(json_dumps(acct_res))
      print("%s: %s" % (acct_res["Id"], name))

if __name__ == "__main__":
   try:
      main()
   except BMCRequestError as exc:
      die(str(exc))
   except Exception:
      traceback.print_exc()
      die("Unhandled exception!")

