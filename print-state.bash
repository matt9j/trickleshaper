#! /usr/bin/env bash

IFACE=eth1

tc -g -s -p qdisc show dev $IFACE
tc -g -s -p class show dev $IFACE
tc -g -s -p filter show dev $IFACE

