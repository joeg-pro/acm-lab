#!/bin/bash

# External data source script for Terraform that determines the latest GAP VM template
# available.  Used to resolve "latest" template-name specs to an actual template name.

# Requires:
# - govc
# - jq

me=$(basename "$0")

tmp_dir=$(mktemp -td "$me.XXXXXXXX")
dbg_file="$tmp_dir/debug"

# The "query' input stuff to an external data source is conveyed as JSON input
# provided on stdin.  Capture what we were given.
cat > "$tmp_dir/input"

# Harvest what we actually got/recognize as inputs.

fields="vcenter_server vcenter_username vcenter_password"
fields+=" vsphere_datacenter vsphere_datastore template_pattern"

# BUild JQ expression to convert JSON input into Bash expression that sets vars.
jq_expr=""
for f in $fields; do
   jq_expr+=" $f=\(.$f)"
done

# Run it on input.
eval $(jq -r "@sh \"$jq_expr\"" "$tmp_dir/input")

# Check that all expected vars are set.

fields_omitted=0
for f in $fields; do
   eval "var_value=\"\$$f\""
   # echo "$f: $var_value" >> $dbg_file
   if [[ "$var_value" == "null" ]]; then
      >&2 echo "Error: Required query property $f is not defined."
      fields_omitted=1
   fi
done
if [[ $fields_omitted -eq 1 ]]; then
   exit 5
fi

# Use inputs to set some stuff GOVC expects/requires.

export GOVC_INSECURE=1
export GOVC_URL="https://$vcenter_server/sdk"
export GOVC_USERNAME="$vcenter_username"
export GOVC_PASSWORD="$vcenter_password"
export GOVC_DATACENTER="$vsphere_datacenter"
export GOVC_DATASTORE="$vsphere_datastore"

govc find -type m "./vm" -config.template true  > "$tmp_dir/all-template-paths"
if [[ $? -ne 0 ]]; then
   >&2 echo "Error:  Could not list all templates via govc."
   rm -rf "$tmp_dir"
   exit 4
fi

# Reduce to templates of the kind we're looking for.

grep "/$template_pattern" "$tmp_dir/all-template-paths" > "$tmp_dir/template-paths"

# Reduce template names to a list of data suffixes

while read templ_path; do

   # Reduce to just the template name (drop eg. ./vm/VM Templates prefix)
   templ_name=${templ_path##*/}

   # Tack on to our collection of suffixes.
   echo $templ_name >> $tmp_dir/template-names

done < $tmp_dir/template-paths

# Sort date stamps numerically and take the largest.
latest_template=$(sort -r $tmp_dir/template-names | head -n1)
if [[ -z "$latest_template" ]]; then
   latest_template="no-template-found"
fi

# Blurt resulting template name as JSON.

latest_template_name="$latest_template"
jq -n -c -M --arg template_name "$latest_template_name" '{"template_name":$template_name}'

# echo "Debug:"
# cat "$dbg_file"

rm -rf "$tmp_dir"

