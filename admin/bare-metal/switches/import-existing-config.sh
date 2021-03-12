#!/bin/bash

# Currently only imports stuff from 1G Swtich #1.

tf="terraform-new"

$tf import module.fog01_sw_conn.junos_interface_physical.nic1_sw_port ge-0/0/0
$tf import module.fog01_sw_conn.junos_interface_physical.nic2_sw_port ge-0/0/1

$tf import module.fog02_sw_conn.junos_interface_physical.nic1_sw_port ge-0/0/2
$tf import module.fog02_sw_conn.junos_interface_physical.nic2_sw_port ge-0/0/3

$tf import module.fog03_sw_conn.junos_interface_physical.nic1_sw_port ge-0/0/4
$tf import module.fog03_sw_conn.junos_interface_physical.nic2_sw_port ge-0/0/5

$tf import module.fog04_sw_conn.junos_interface_physical.nic1_sw_port ge-0/0/6
$tf import module.fog04_sw_conn.junos_interface_physical.nic2_sw_port ge-0/0/7

$tf import module.fog05_sw_conn.junos_interface_physical.nic1_sw_port ge-0/0/8
$tf import module.fog05_sw_conn.junos_interface_physical.nic2_sw_port ge-0/0/9

$tf import module.fog06_sw_conn.junos_interface_physical.nic1_sw_port ge-0/0/10
$tf import module.fog06_sw_conn.junos_interface_physical.nic2_sw_port ge-0/0/11

#

$tf import module.fog07_sw_conn.junos_interface_physical.nic1_sw_port ge-0/0/12
$tf import module.fog07_sw_conn.junos_interface_physical.nic2_sw_port ge-0/0/13

$tf import module.fog08_sw_conn.junos_interface_physical.nic1_sw_port ge-0/0/14
$tf import module.fog08_sw_conn.junos_interface_physical.nic2_sw_port ge-0/0/15

$tf import module.fog09_sw_conn.junos_interface_physical.nic1_sw_port ge-0/0/16
$tf import module.fog09_sw_conn.junos_interface_physical.nic2_sw_port ge-0/0/17

$tf import module.fog10_sw_conn.junos_interface_physical.nic1_sw_port ge-0/0/18
$tf import module.fog10_sw_conn.junos_interface_physical.nic2_sw_port ge-0/0/19

$tf import module.fog11_sw_conn.junos_interface_physical.nic1_sw_port ge-0/0/20
$tf import module.fog11_sw_conn.junos_interface_physical.nic2_sw_port ge-0/0/21

$tf import module.fog12_sw_conn.junos_interface_physical.nic1_sw_port ge-0/0/22
$tf import module.fog12_sw_conn.junos_interface_physical.nic2_sw_port ge-0/0/23

#

$tf import module.fog13_sw_conn.junos_interface_physical.nic1_sw_port ge-0/0/24
$tf import module.fog13_sw_conn.junos_interface_physical.nic2_sw_port ge-0/0/25

$tf import module.fog14_sw_conn.junos_interface_physical.nic1_sw_port ge-0/0/26
$tf import module.fog14_sw_conn.junos_interface_physical.nic2_sw_port ge-0/0/27

$tf import module.fog15_sw_conn.junos_interface_physical.nic1_sw_port ge-0/0/28
$tf import module.fog15_sw_conn.junos_interface_physical.nic2_sw_port ge-0/0/29

$tf import module.fog16_sw_conn.junos_interface_physical.nic1_sw_port ge-0/0/30
$tf import module.fog16_sw_conn.junos_interface_physical.nic2_sw_port ge-0/0/31

$tf import module.fog17_sw_conn.junos_interface_physical.nic1_sw_port ge-0/0/32
$tf import module.fog17_sw_conn.junos_interface_physical.nic2_sw_port ge-0/0/33

$tf import module.fog18_sw_conn.junos_interface_physical.nic1_sw_port ge-0/0/34
$tf import module.fog18_sw_conn.junos_interface_physical.nic2_sw_port ge-0/0/35
