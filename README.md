### This is still a rough draft

This repository is mostly a backup at the moment, the code isn't finalized or well documented. The deepvar-simple-SG.wdl should be used with caution because it will most likely overload a server with 16 cores and 32GB RAM due to some bug, or feature, in call_variants.zip that will use as many threads as there are shards. I don't know how this is determined exactly, but it seems like if you use e.g 16 shards, the call_variants.zip process will use 16 threads _per process_, meaning it will in a worst case scenario use 16*16 threads. I will investigate this further when I get the opportunity.
