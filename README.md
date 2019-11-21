Trickleshaper
=============

This shaping script was developed to support host-fair bandwidth
allocation in networks with very low aggregate backhaul bandwidth
(<500k) and on hosts where fq_cake is not yet available. It is
loosely adapted from Wondershaper's
(https://github.com/magnific0/wondershaper) simple CLI and with much
technical inspiration from the Bufferbloat Project's
(https://www.bufferbloat.net/projects/) excellent work. It has not
been optimized for high throughput networks. If you find yourself
operating at throughputs consistently higher than 1Mbps, you should
strongly consdier fq_codel or fq_cake, which are much more general,
flexible, and optimized.

This script as written assumes a local area /24 network, and creates
256 host specific queues keyed on the last octet of the IP
address. If you're reading this and running a different size
network, you should probably modify to meet your network specific
conditions.

This code has no warranty to the greatest extent of the law, implied
or otherwise. Use at your own risk.

Copyright 2019 Matthew Johnson <matt9j@cs.washington.edu>
Licensed under the GPLv3 https://www.gnu.org/licenses/gpl-3.0.en.html
