#! /usr/bin/env bash

IFACE=eth1

tc -g -s qdisc show dev $IFACE
tc -g -s class show dev $IFACE
tc -g -s filter show dev $IFACE
