Notes dealing with linux TC in 2019, on debian stretch with kernel 4.9.0-9-amd64

The QFQ qdisc behaves a little differently than htb or other qdiscs
mentioned online. It seems like QFQ gets confused if you don't have
internal filters (I.E. if you try and filter jump directly to one of
its subclasses!)

The ip proto filter parameters are confusing, and not well documented
as far as I can find.

There is some burstiness in traffic with tbf -> qfq -> fq_codel, on the order of seconds, not ms like I would expect. I am not sure if this is a property of codel, or batching of things in qfq, or what...
