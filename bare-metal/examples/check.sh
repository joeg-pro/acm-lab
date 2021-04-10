#!/bin/bash

# Informal.  WIP.
#
# Needs:
# - Python 3

me=$(basename $0)
my_dir=$(dirname $(readlink -f $0))

install_config="./install-config.yaml"

tmp_dir=$(mktemp -dt "$me.XXXXXXXX")

function gethostbyname {

ghbn_file="$tmp_dir/gethostbyname.py"

cat <<E-O-D > "$ghbn_file"
import socket
try:
   print(socket.gethostbyname("$1"))
except:
   pass
E-O-D
python3 "$ghbn_file"
}


# Get the fully-qualified cluster name.

base_domain=$(yq -r ".baseDomain"  "$install_config")
cluster_name=$(yq -r ".metadata.name"  "$install_config")
full_cluster_name="$cluster_name.$base_domain"

echo "Full cluster name: $full_cluster_name"

# Find the GAP VM being used
gap_uri=$(yq -r ".platform.baremetal.libvirtURI"  "$install_config")
user_at_host=${gap_uri#*//}
user_at_host=${user_at_host%%/*}
gap_host_name=${user_at_host#*@}
echo "GAP hostname: $gap_host_name"

gap_ip=$(gethostbyname "$gap_host_name")
echo "GAP private IP address: $gap_ip"

# Check for required DNS entries, and that both point to the same thing.
# Would like to verify that they point to the GAP VM, but we can't determine
# the GAP VM external IP address by looking at install-config.yaml.

echo "Checking DNS entries."

api_ip=$(gethostbyname "api.$full_cluster_name")
if [[ -z "$api_ip" ]]; then
   >^2 echo "Error:  Can't resolve api.$full_cluster_name."
fi
echo "api.<cluster> resolves to: $api_ip"

ingress_ip=$(gethostbyname "test.apps.$full_cluster_name")
if [[ -z "$api_ip" ]]; then
   >^2 echo "Error:  Can't resolve *.apps.$full_cluster_name."
fi
echo "*.apps.<cluster> reference resolves to: $ingress_ip"

tmp_dir=$(mktemp -dt "$me.XXXXXXXX")

# Get list of hosts since we're going to need to process each of them.

hosts_json="$tmp_dir/hosts.json"
this_host_bmc_json="$tmp_dir/this-host-bmc.json"
this_host_system_json="$tmp_dir/this-host-system.json"

yq ".platform.baremetal.hosts" "$install_config" > $hosts_json
host_names=$(jq -r ".[] | .name"  "$hosts_json")

for host_name in $host_names; do
   echo "Checking access to BMC for $host_name"
   jq -c ".[] | select (.name == \"$host_name\") | .bmc" $hosts_json > $this_host_bmc_json
   bmc_url=$(jq -r ".address" "$this_host_bmc_json")
   bmc_username=$(jq -r ".username" "$this_host_bmc_json")
   bmc_password=$(jq -r ".password" "$this_host_bmc_json")

   # The address/URL in installl-config.yaml is using protocol redfish:// and specifies
   # the path for the System resource.  Turn it into the corresponding https URL.

   rf_system_url="https://${bmc_url#*//}"
   url_no_protocol="${bmc_url#*//}"
   https_base_url="https://${url_no_protocol%%/*}"

   # Test access to the Redfish system resource as specified in install-config.
   # Note: Sushy will actually use session authentication (via SessionService) but checking
   # access via basic auth is probably good enough.

   status=$(curl -k -u"$bmc_username:$bmc_password" -s -o "$this_host_system_json" -w "%{http_code}"  "$rf_system_url")
   if [[ "$status" != "200" ]]; then
      >&2 echo "Error: Status $status when getting System resource from BMC."
   else
      echo "Ok."
   fi

done

rm -rf $tmp_dir


