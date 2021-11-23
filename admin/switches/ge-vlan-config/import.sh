#!/bin/bash

# Imports existing switch config in case a current tfstate has been lost.

# We need TF >= 0.15 at this alias.
tf="terraform-15"

# The TF config provides an "import_info" output to let this script import
# everything the TF defines "automatically".

# For special new-switch setup runs...
special_import_json="./new-switch-import.json"
use_special_import_json=0
if [[ -f "$special_import_json" ]]; then
   use_special_import_json=1
fi

tmp_import_json="./import-info.json"
tmp_import_lines="./import-info.lines"

if [[ $use_special_import_json -ne 1 ]]; then
   $tf refresh > /dev/null
   $tf output -json import_info > $tmp_import_json
else
   cp $special_import_json $tmp_import_json
fi

cat $tmp_import_json | jq -rc '.[] | "\(.resource) \(.id)"' > $tmp_import_lines

while read import_line; do
   resource=${import_line% *}
   id=${import_line#* }
   "$tf" "import"  "$resource" "$id"
done < $tmp_import_lines

rm -f $tmp_import_json $tmp_import_lines

