#! /usr/bin/env bash

#IFACE=eth1
IFACE=enx009f9e90079b
IFB=ifb0

echo "---Start Egress---"
echo "    ---Clear existing"
tc qdisc del dev $IFACE root
tc qdisc del dev $IFACE ingress

echo "    ---Add root qdiscs"
tc qdisc add dev $IFACE root handle 1: tbf rate 500kbit burst 30kbit latency 10ms
# The latency parameter does not matter since we overwrite the TBF's
# internal qdisc with QFQ, but it is required. See `$man tc-tbf` for
# more information.

tc qdisc add dev $IFACE parent 1:1 handle 2: qfq

echo "    ---Add app classes"
# 2:1 for EF and voice traffic
tc class add dev $IFACE parent 2: classid 2:1 qfq weight 20
# 2:2 for small packets (dangerous since not flow aware, could cause reordering)
# TODO(matt9j) Use CAKE to target small *flows*
tc class add dev $IFACE parent 2: classid 2:2 qfq weight 20
# 2:3 normal best effort traffic
tc class add dev $IFACE parent 2: classid 2:3 qfq weight 10
# Bulk
tc class add dev $IFACE parent 2: classid 2:4 qfq weight 5

for appIndex in `seq 1 4`
do
    echo "    ===============Class "$appIndex"==========="
    echo "        ---Use QFQ in each class"
    qdiscHandle=2$appIndex
    tc qdisc add dev $IFACE parent 2:$appIndex handle $qdiscHandle: qfq

    echo "        ---Add shapers per ip"
    for i in `seq 1 256`
    do
        classid=$qdiscHandle:$(printf %x $i)
        tc class add dev $IFACE parent $qdiscHandle: classid $classid qfq weight 10
        tc qdisc add dev $IFACE parent $classid sfq\
           perturb 30 headdrop probability 0.5 redflowlimit 20000 ecn harddrop
    done

    echo "        ---Add ip source filter"
    tc filter add dev $IFACE parent $qdiscHandle: protocol all prio 1\
       handle 0xff$qdiscHandle\
       flow map key nfct-src and 0xff divisor 256 baseclass $qdiscHandle:1
done

echo "    ---Add app class filters"
# TODO(matt9j) Identify WA voice and send to top band
# TODO(matt9j) Identify heavy flows and send to bottom band

# Prioritize DSCP EF
tc filter add dev $IFACE parent 2: protocol ip prio 10 u32 \
   match ip dsfield 0xb8 0xfc flowid 2:1

tc filter add dev $IFACE parent 2: protocol ip prio 10 u32 \
   match ip6 priority 0xb8 0xfc flowid 2:1

# Prioritize Small packets (<128 bytes payload)
tc filter add dev $IFACE parent 2: protocol ip prio 12 u32 \
   match u16 0x0000 0xff80 at 2 flowid 2:2

tc filter add dev $IFACE parent 2: protocol ip prio 12 u32 \
   match u16 0x0000 0xff80 at 4 flowid 2:2

# By default send all traffic to the middle band.
# Large prio ("low priority") ensures other filters take precedence
# over this default.
tc filter add dev $IFACE parent 2: prio 1000 matchall flowid 2:3

echo ""
echo "---Start Ingress--"
echo "    ---Add IFB"
# Add the IFB interface
modprobe ifb numifbs=1
ip link set dev $IFB up

echo "    ---Clear existing ingress"
tc qdisc del dev $IFB ingress
tc qdisc del dev $IFB root

echo "    ---Redirect to the ifb"
# Redirect ingress (incoming) to egress ifb0
tc qdisc add dev $IFACE handle ffff: ingress
tc filter add dev $IFACE parent ffff: matchall action mirred egress redirect dev $IFB

echo "    ---Add root qdiscs"
tc qdisc add dev $IFB root handle 1: tbf rate 500kbit burst 30kbit latency 10ms
# The latency parameter does not matter since we overwrite the TBF's
# internal qdisc with QFQ, but it is required. See `$man tc-tbf` for
# more information.
tc qdisc add dev $IFB parent 1: handle 2: qfq

echo "    ---Add app classes"
# 2:1 for EF and voice traffic
tc class add dev $IFB parent 2: classid 2:1 qfq weight 20
# 2:2 for small packets (dangerous since not flow aware, could cause reordering)
# TODO(matt9j) Use CAKE to target small *flows*
tc class add dev $IFB parent 2: classid 2:2 qfq weight 20
# 2:3 normal best effort traffic
tc class add dev $IFB parent 2: classid 2:3 qfq weight 10
# Bulk
tc class add dev $IFB parent 2: classid 2:4 qfq weight 5

echo "    ---Add admin shortcut"
tc class add dev $IFB parent 2: classid 2:5 qfq weight 30
tc qdisc add dev $IFB parent 2:5 sfq\
   perturb 30 headdrop probability 0.5 redflowlimit 20000 ecn harddrop

# Add exception filter
tc filter add dev $IFB parent 2: protocol ip prio 1 handle 0x1337 \
   u32 match ip dst 192.168.151.183 flowid 2:5


for appIndex in `seq 1 4`
do
    echo "    ===============Class "$appIndex"==========="
    echo "        ---Use QFQ in each class"
    qdiscHandle=2$appIndex
    tc qdisc add dev $IFB parent 2:$appIndex handle $qdiscHandle: qfq

    echo "        ---Add shapers per ip"
    for i in `seq 1 256`
    do
        classid=$qdiscHandle:$(printf %x $i)
        tc class add dev $IFB parent $qdiscHandle: classid $classid qfq weight 10
        tc qdisc add dev $IFB parent $classid sfq\
           perturb 30 headdrop probability 0.5 redflowlimit 20000 ecn harddrop
    done

    echo "        ---Add ip dest filter"
    tc filter add dev $IFB parent $qdiscHandle: protocol all prio 1\
       handle 0xff$qdiscHandle\
       flow map key nfct-dst and 0xff divisor 256 baseclass $qdiscHandle:1
done

echo "    ---Add app class filters"
# TODO(matt9j) Identify WA voice and send to top band
# TODO(matt9j) Identify heavy flows and send to bottom band

# Prioritize DSCP EF
tc filter add dev $IFB parent 2: protocol ip prio 10 u32 \
   match ip dsfield 0xb8 0xfc flowid 2:1

tc filter add dev $IFB parent 2: protocol ip prio 10 u32 \
   match ip6 priority 0xb8 0xfc flowid 2:1

# Prioritize Small packets (<128 bytes payload)
tc filter add dev $IFB parent 2: protocol ip prio 12 u32 \
   match u16 0x0000 0xff80 at 2 flowid 2:2

tc filter add dev $IFB parent 2: protocol ip prio 12 u32 \
   match u16 0x0000 0xff80 at 4 flowid 2:2

# By default send all traffic to the middle band.
# Large prio ("low priority") ensures other filters take precedence
# over this default.
tc filter add dev $IFB parent 2: prio 1000 matchall flowid 2:3
