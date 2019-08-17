#! /usr/bin/env bash

IFACE=eth1
IFB=ifb0

echo "-------------------Clear that shit----------------"
tc qdisc del dev $IFACE root
tc qdisc del dev $IFACE ingress

echo "-------------------Show it's cleared----------------"
tc -g -s qdisc show dev $IFACE
tc -g -s class show dev $IFACE
tc -g -s filter show dev $IFACE

echo "-------------------Add root----------------"

tc qdisc add dev $IFACE root handle 1: tbf rate 500kbit burst 100kbit latency 10ms
# The latency parameter does not matter since we overwrite the TBF's
# internal qdisc with QFQ, but it is required. See `$man tc-tbf` for
# more information.

echo "------------------Add parent qfq-----------"

tc qdisc add dev $IFACE parent 1:1 handle 2: qfq

echo "-------------------Add shapers per ip----------------"
for i in `seq 1 256`
do
classid=2:$(printf %x $i)
tc class add dev $IFACE parent 2: classid $classid qfq weight 10
tc qdisc add dev $IFACE parent $classid fq_codel target 10ms
done

echo "-------------------Add filter--------------"
#tc filter add dev $IFACE parent 1: matchall flowid 2:
#tc filter add dev $IFACE parent 2: matchall flowid 2:1

tc filter add dev $IFACE parent 2: protocol all prio 1 handle 0x1337 \
   flow map key nfct-src and 0xff divisor 256 baseclass 2:1
#This is where we maybe want to change to destIP

echo "-------------------Print end state----------------"

tc -g -s qdisc show dev $IFACE
tc -g -s class show dev $IFACE
tc -g -s filter show dev $IFACE


echo "-------------------Start ingress magic------------"
# Add the IFB interface
modprobe ifb numifbs=1
ip link set dev $IFB up

tc qdisc del dev $IFB ingress
tc qdisc del dev $IFB root

# Redirect ingress (incoming) to egress ifb0
tc qdisc add dev $IFACE handle ffff: ingress
tc filter add dev $IFACE parent ffff: matchall action mirred egress redirect dev $IFB

echo "-------------------Start adding qdiscs------------"
# Add class and top level rules for virtual
tc qdisc add dev $IFB root handle a1: tbf rate 500kbit burst 100kbit latency 10ms
# The latency parameter does not matter since we overwrite the TBFs
# internal qdisc with QFQ, but it is required. See `$man tc-tbf` for
# more information.
tc qdisc add dev $IFB parent a1: handle a2: qfq

for i in `seq 1 256`
do
classid=a2:$(printf %x $i)
tc class add dev $IFB parent a2: classid $classid qfq weight 10
tc qdisc add dev $IFB parent $classid fq_codel target 10ms
done

tc class add dev $IFB parent a2: classid a2:fff qfq weight 10
tc qdisc add dev $IFB parent a2:fff fq_codel target 10ms

echo "-------------------Start adding filters------------"
# Add flow hash filter
tc filter add dev $IFB parent a2: protocol all prio 2 handle 0x2337 \
   flow map key nfct-dst and 0xff divisor 256 baseclass a2:1

tc filter add dev $IFB parent a2: protocol ip prio 1 handle 0x3337 \
   u32 match ip dst 192.168.41.101 flowid a2:fff

tc -g -s qdisc show dev $IFB
tc -g -s class show dev $IFB
tc -g -s filter show dev $IFB
