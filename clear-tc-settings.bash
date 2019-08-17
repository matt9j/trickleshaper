#! /usr/bin/env bash

IFACE=eth1
IFB=ifb0

tc qdisc del dev $IFB ingress
tc qdisc del dev $IFB root

tc qdisc del dev $IFACE root
tc qdisc del dev $IFACE ingress

echo "-------------------Show iface is cleared----------------"
tc -g -s qdisc show dev $IFACE
tc -g -s class show dev $IFACE
tc -g -s filter show dev $IFACE

echo "-------------------Show ifb is cleared----------------"
tc -g -s qdisc show dev $IFB
tc -g -s class show dev $IFB
tc -g -s filter show dev $IFB
