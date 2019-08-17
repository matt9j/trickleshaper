#! /usr/bin/env bash

sudo ip link add dummy1 type dummy
sudo ip addr add 192.168.41.101 dev dummy0
sudo ip addr add 192.168.41.102 dev dummy1
