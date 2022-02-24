#!/bin/bash

# This script is an admin do-on-many-machines convenience utility.
# Edit the stuff that terminates the machine list as needed.

machines=""
slot_00_fog_machines="fog01 fog02 fog03 fog04 fog05 fog06"
slot_02_fog_machines="fog07 fog08 fog09 fog10 fog11 fog12"
slot_04_fog_machines="fog13 fog14 fog15 fog16 fog17 fog18"
slot_06_fog_machines="fog19 fog20 fog21 fog22 fog23 fog24"
slot_08_fog_machines="fog25 fog26 fog27 fog28 fog29 fog30"
slot_10_fog_machines="fog31 fog32 fog33 fog34 fog35 fog36"
slot_12_fog_machines="fog37 fog38 fog39 fog40 fog41 fog42"
slot_14_fog_machines="fog43 fog44 fog45 fog46 fog47 fog48 fog49 fog50 fog51"

vapor_machienss="vapor01 vapor02"
mist_vsphere_machines="mist01 mist02 mist03 mist04 mist05"

steam_machines="steam01 steam02"
mist_kvm_machines="mist06 mist07 mist08 mist09 mist10 mist11 mist12"

run_on_machines="$slot_14_fog_machines"

# Creds entry names:
accounts_to_create="bmc-admin bmc-ome bmc-bmc"

accounts=()
for a in $accounts_to_create; do
   creds=$(get-acm-lab-creds -a "$a")
   accounts+=("$creds")
done

for m in $run_on_machines; do
   echo "Running for $m."
   for a in "${accounts[@]}"; do
      username=$(echo "$a" | jq -r ".username")
      password=$(echo "$a" | jq -r ".password")
      role=$(echo "$a" | jq -r ".role")

      # echo "Creating account for $username as $role (pw: \"$password\")."
      echo "Creating account for $username as $role."
      "./create-bmc-account" -D $m "$username" "$password" "$role"
   done
done

# Also handy for resetting account creds:

# ./delete-bmc-account -D $m "$username"
# ./set-bmc-account-password $m "$username" "$password

