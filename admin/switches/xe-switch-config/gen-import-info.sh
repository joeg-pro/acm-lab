#!/bin/bash

# We need TF >= 0.15 at this alias.
tf="terraform-15"

# The TF config provides an "import_info" output to let this script import
# everything the TF defines "automatically".

tmp_import_json="./import-info.json"

$tf refresh > /dev/null
$tf output -json import_info > $tmp_import_json
