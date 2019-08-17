#! /usr/bin/env bash

IFACE=eth1
IFB=ifb0

echo "------------------"
echo "---Start Egress---"
echo "------------------"
echo "-------------------Clear existing----------------"
tc qdisc del dev $IFACE root
tc qdisc del dev $IFACE ingress

echo "-------------------Add root ratelimit----------------"
tc qdisc add dev $IFACE root handle 1: tbf rate 500kbit burst 30kbit latency 10ms
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
tc qdisc add dev $IFACE parent $classid sfq perturb 30 headdrop probability 0.5 redflowlimit 20000 ecn harddrop
done

echo "-------------------Add ip source filter--------------"
#tc filter add dev $IFACE parent 2: matchall flowid 2:1

tc filter add dev $IFACE parent 2: protocol all prio 1 handle 0x1337 \
   flow map key nfct-src and 0xff divisor 256 baseclass 2:1


echo "------------------"
echo "---Start Ingress--"
echo "------------------"
echo "-------------------Add IFB------------"
# Add the IFB interface
modprobe ifb numifbs=1
ip link set dev $IFB up

echo "-------------------Clearing existing ingress------------"
tc qdisc del dev $IFB ingress
tc qdisc del dev $IFB root

echo "-------------------Redirect to ifb------------"
# Redirect ingress (incoming) to egress ifb0
tc qdisc add dev $IFACE handle ffff: ingress
tc filter add dev $IFACE parent ffff: matchall action mirred egress redirect dev $IFB

echo "-------------------Add qdiscs------------"
tc qdisc add dev $IFB root handle a1: tbf rate 500kbit burst 30kbit latency 10ms
# The latency parameter does not matter since we overwrite the TBF's
# internal qdisc with QFQ, but it is required. See `$man tc-tbf` for
# more information.
tc qdisc add dev $IFB parent a1: handle a2: qfq

for i in `seq 1 256`
do
classid=a2:$(printf %x $i)
tc class add dev $IFB parent a2: classid $classid qfq weight 10
tc qdisc add dev $IFB parent $classid sfq perturb 30 headdrop probability 0.5 redflowlimit 20000 ecn harddrop
done

tc class add dev $IFB parent a2: classid a2:fff qfq weight 20
tc qdisc add dev $IFB parent a2:fff sfq perturb 30 headdrop probability 0.5 redflowlimit 20000 ecn harddrop

echo "-------------------Add ip dest filter------------"
# Add flow hash filter
tc filter add dev $IFB parent a2: protocol all prio 2 handle 0x2337 \
   flow map key nfct-dst and 0xff divisor 256 baseclass a2:1

# Add exception filter
tc filter add dev $IFB parent a2: protocol ip prio 1 handle 0x3337 \
   u32 match ip dst 192.168.41.101 flowid a2:fff
