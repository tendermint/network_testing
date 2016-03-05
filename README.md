# network testing

Some utilities for putting up tendermint test nets and benchmarking throughput and latency

# run all the experiments:

`bash run_experiments.sh <machine prefix> <results dir>`

Each experiment loads (4, 8, 16 ... ) validators committing blocks of (100, 1000, 10000) transactions.
Validators load transactions in-process and start committing them once we're sure they're all loaded and synced.
Once the mempools are empty, we grab the artifacts, and compute the mean block latency and the tx throughput,
using the times the 2/3+1th validator committed each block.


