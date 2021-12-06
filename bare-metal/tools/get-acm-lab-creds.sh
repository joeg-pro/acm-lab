#!/bin/bash

# Provides creds info from the creds file.

me=$(basename $0)
# my_dir=$(dirname $(readlink -f $0))

opt_flags="a"
emit_full_entry=0

while getopts "$opt_flags" OPTION; do
   case "$OPTION" in
      a) emit_full_entry=1
         ;;
      ?) exit 1
         ;;
   esac
done
shift "$(($OPTIND -1))"

# Try current env var names first
data_yaml="${ACM_LAB_MACHINE_INFO}"
creds_yaml="${ACM_LAB_MACHINE_CREDS}"

# And then deprecated ones for caompaibility
creds_yaml="${creds_yaml:-$FOG_MACHINE_CREDS}"

# Complaign if something is missing.
if [[ ! -f "$creds_yaml" ]]; then
   >&2 echo "Error: Can not find ACM Lab creds yaml file."
   exit 5
fi

entry_id="$1"
if [[ -z "entry_id" ]]; then
   >&2 echo "Error: Entry-id is required."
   exit 5
fi

entry_data=$(yq -c ".global[\"$entry_id\"]" "$creds_yaml")
if [[ "$entry_data" == "null" ]]; then
   >&2 echo "Error: Creds entry for \"$entry_id\" not found."
   exit 5
fi

# Most callers only want username and password, but special onces
# might want everything in the entry.

if [[ $emit_full_entry -eq 1 ]]; then
   echo "$entry_data"
else
   username=$(echo "$entry_data" | jq -r ".username")
   password=$(echo "$entry_data" | jq -r ".password")
   echo "{\"username\": \"$username\", \"password\": \"$password\"}"
fi

