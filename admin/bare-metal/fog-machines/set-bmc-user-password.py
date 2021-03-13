#!/bin/python3

# Author: J. M. Gdaniec, Jan 2021

from bmc_common import *

import requests
import json
import os.path
import sys
import traceback

# Main:

try:

   # set_dbg_volume_level(3)

   if len(sys.argv) < 4:
      emsg("Syntax: %s <fog-name> <username> <new-password>" % os.path.basename(sys.argv[0]))
      exit(5)

   machine_name = sys.argv[1]
   account_name = sys.argv[2]
   account_password = sys.argv[3]

   bmc_conn = FogBMCConnection(sys.argv[1], as_admin=True)
   bmc_conn.set_account_password(account_name, account_password)
   blurt("Password successfully set for account \"%s\"." % (account_name))


except BMCRequestError as exc:
   die(str(exc))

except Exception:
   traceback.print_exc()
   die("Unhandled exception!")



