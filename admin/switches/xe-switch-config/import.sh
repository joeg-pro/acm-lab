#!/bin/bash

# Imports existing switch config in case a current tfstate has been lost.

# We need TF >= 0.15 at this alias.
tf="terraform-15"

# The TF config provides an "import_info" output to let this script import
# everything the TF defines "automatically".

tmp_import_lines="./import-info.lines"

$tf refresh > /dev/null
$tf output -json import_info | jq -rc '.[] | "\(.resource) \(.id)"' > $tmp_import_lines

while read import_line; do
   resource=${import_line% *}
   id=${import_line#* }
   "$tf" "import"  "$resource" "$id"
done < $tmp_import_lines

rm -f "$tmp_import_lines"
