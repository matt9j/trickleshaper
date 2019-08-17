#! /usr/bin/env bash

IFACE=eth1
IFB=ifb0

echo "=================================="
echo "===============EGRESS============="
echo "=================================="
tc -g -s -p qdisc show dev $IFACE
tc -g -s -p class show dev $IFACE
tc -g -s -p filter show dev $IFACE

echo "=================================="
echo "==============INGRESS============="
echo "=================================="
tc -g -s -p qdisc show dev $IFB
tc -g -s -p class show dev $IFB
tc -g -s -p filter show dev $IFB
