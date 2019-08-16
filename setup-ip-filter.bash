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

tc qdisc add dev $IFACE root handle 1: htb default 1
tc class add dev $IFACE parent 1: classid 1:1 htb rate 10Mbit
tc class add dev $IFACE parent 1: classid 1:2 htb rate 10Mbit
tc qdisc add dev $IFACE parent 1:2 handle 30: sfq perturb 10 quantum 6000

echo "------------------Add parent qfq-----------"

tc qdisc add dev $IFACE parent 1:1 handle 2: qfq

echo "-------------------Add shapers per ip----------------"
tc class add dev $IFACE parent 2: classid 2:1 qfq weight 10
tc qdisc add dev $IFACE parent 2:1 handle 40: pfifo limit 30

tc class add dev $IFACE parent 2: classid 2:2 qfq weight 10
tc qdisc add dev $IFACE parent 2:2 handle 50: pfifo limit 30

echo "-------------------Add filter--------------"
tc filter add dev $IFACE parent 1:1 matchall flowid 2:
#tc filter add dev $IFACE parent 2: matchall flowid 2:1

tc filter add dev $IFACE parent 2: protocol all prio 10 handle 0x1337 \
   flow hash keys src divisor 2 baseclass 2:1
#This is where we maybe want to change to destIP

#tc filter add dev $IFACE parent 2:1 matchall
#tc filter add dev $IFACE parent 1: protocol ip prio 10 u32 \
#   match ip dst 0.0.0.0/0 flowid 2:2

echo "-------------------Print end state----------------"

tc -g -s qdisc show dev $IFACE
tc -g -s class show dev $IFACE
tc -g -s filter show dev $IFACE
