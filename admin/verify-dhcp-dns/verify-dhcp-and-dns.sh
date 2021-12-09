#!/bin/bash

# Run this from a VMWare VM with NIC ens160 connected to the labe
# data network 10.1.158.0/24.

verify_list="./dhcp-dns-verify-list.txt"

while read line; do
   name=$(echo $line| cut -d" " -f1)
   mac=$(echo $line| cut -d" " -f2)
   expected_ip=$(echo $line| cut -d" " -f3)

   ok=1
   dns_ip=$(./gethostbyname "$name.acm.lab.eng.rdu2.redhat.com")
   if [[ "$dns_ip" != "$expected_ip" ]]; then
      echo "Error: $name DNS wrong ($dns_ip)"
      ok=0
   fi

   dhcp_ip=$(sudo ./check-dhcp -i ens160 -m "$mac"|grep "of IP address" | cut -d" " -f10)
   if [[ "$dhcp_ip" != "$expected_ip" ]]; then
      echo "Error: $name DHCP wrong ($dhcp_ip)"
      ok=0
   fi

   if [[ $ok -eq 1 ]]; then
      echo "$name: DNS and DHCP OK ($dhcp_ip)"
   fi

done < "$verify_list"

