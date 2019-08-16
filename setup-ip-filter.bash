#! /usr/bin/env bash

IFACE=eth1

echo "-------------------Clear that shit----------------"
tc qdisc del dev $IFACE root
tc qdisc del dev $IFACE ingress

echo "-------------------Show it's cleared----------------"
tc -g -s qdisc show dev $IFACE
tc -g -s class show dev $IFACE
tc -g -s filter show dev $IFACE

echo "-------------------Add root----------------"

tc qdisc add dev $IFACE root handle 1: qfq

echo "-------------------Add filter--------------"
tc filter add dev $IFACE parent 1: protocol ip prio 10 handle 0x1337 \
   flow hash keys src divisor 2 baseclass 1:1
#This is where we maybe want to change to destIP

tc filter add dev $IFACE parent 1: protocol ip prio 9 u32 \
        match ip dst 0.0.0.0/0 flowid 11:

echo "-------------------Add shapers per ip----------------"
tc class add dev $IFACE parent 1: classid 1:1 qfq weight 10
tc qdisc add dev $IFACE parent 1:1 handle 11: tbf rate 500kbit burst 1mbit latency 10ms

tc class add dev $IFACE parent 1: classid 1:2 qfq weight 10
tc qdisc add dev $IFACE parent 1:2 handle 12: tbf rate 500kbit burst 1mbit latency 10ms

echo "-------------------Print end state----------------"

tc -g -s qdisc show dev $IFACE
tc -g -s class show dev $IFACE
tc -g -s filter show dev $IFACE
