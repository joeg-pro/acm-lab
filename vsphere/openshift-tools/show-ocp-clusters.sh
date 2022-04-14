#!/bin/bash

# Shows existing OCP clusters by looking for telltale openshift-* tag categories.
#
# Requires:
# - govc
#
# Assumes VSphere URL and creds defined by GOVC_* env variables.

me=$(basename "$0")

tmp_dir=$(mktemp -td $me.XXXXXXXX)
tag_list_file="$tmp_dir/tag-list"

govc tags.ls  > $tag_list_file

while read line; do
   tag_value=$(echo "$line" | awk '{print $1}')
   tag_category=$(echo "$line" | awk '{print $2}')

   # Openshift creates tags in cateogires that start with "openshift-*"

   if [[ $tag_category = openshift-* ]]; then
      ids=$(govc tags.attached.ls "$tag_value")
      if [[ -n "$ids" ]]; then
         # We still have things tagged with this tag.
         echo "Cluster id $tag_value:"
         for id in $ids; do
            thing_path=$(govc ls -L "$id")
            echo "   $thing_path ($id)"
         done
      fi
   fi
done < $tag_list_file

rm -rf $tmp_dir


