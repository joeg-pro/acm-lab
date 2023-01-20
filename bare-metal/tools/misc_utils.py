
# Some miscellaneous Python utility functions.

# Assumes: Python 3.6+

import json
import sys
import time


def now():
   return time.time()

# Some message-emitting utilities.

dbg_volume_level = 0

def set_dbg_volume_level(lvl):
   global dbg_volume_level
   dbg_volume_level = lvl

def get_dbg_volume_level():
   return dbg_volume_level

def eprint(*args, **kwargs):
   print(*args, file=sys.stderr, **kwargs)

def emsg(msg, *args, prefix=None):
   if prefix:
      eprint("[%s] Error: %s" % (prefix, msg,), *args)
   else:
      eprint("Error: %s" % msg, *args)

def wmsg(msg, *args, prefix=None):
   if prefix:
      eprint("[%s] Warning: %s" % (prefix, msg,), *args)
   else:
      eprint("Warning: %s" % msg, *args)

def nmsg(msg, *args, prefix=None):
   if prefix:
      eprint("[%s] Note: %s" % (prefix, msg,), *args)
   else:
      eprint("Note: %s" % msg, *args)

def blurt(*args, **kwargs):
   prefix = None
   if "prefix" in kwargs:
      prefix = kwargs["prefix"]
      del kwargs["prefix"]
   if prefix:
      print("[%s]" % prefix, *args, **kwargs)
   else:
      print(*args, **kwargs)

def die(msg, *args):
   eprint("Error: " + msg, *args)
   eprint("Aborting.")
   exit(2)

def dbg(msg, *args, level=1, indent_level=0):
   if level <= dbg_volume_level:
      indenting = " " * (indent_level * 3)
      eprint("DBG: " + indenting + msg, *args)


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

