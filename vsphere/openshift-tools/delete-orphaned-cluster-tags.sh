#!/bin/bash

# Openshift IPI install creates a tag category and tag for each cluster.
# These get orphaned if clusters are deleted manually.
#
# This script finds orphaned tags and deletes them.
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
         echo "Tag $tag_value:"
         for id in $ids; do
            thing_path=$(govc ls -L "$id")
            echo "   $thing_path ($id)"
         done
      else
         echo "Deleting orphaned tag: $tag_value"
         govc tags.rm -c "$tag_category" "$tag_value"
         govc tags.category.rm "$tag_category"
      fi
   fi
done < $tag_list_file

rm -rf $tmp_dir


