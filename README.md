# network testing

Some utilities for putting up tendermint test nets and benchmarking throughput and latency

# run an experiment

`./experiment.sh  <"single" | "multi"> <N> <txs/block> <bytes/tx> <n txs> <machine prefix> <results dir>`

Runs through all the below.

eg. `./experiment.sh multi 4 10000 250 100000 bench results`

# create machines

`./utils/launch.sh <machine prefix> <"single" | "multi"> <start N> <end N> <region>`

Note `<region>` is only used if the second argument is "single"

# start service

`./test_rpc/start.sh <machine prefix> <node data dir> <N>`

Will initialize the data in `<node data dir>`, copy the data to the nodes, and start the container/s.

# run the test


```
# massage the config file
echo "{}" > mon.json
netmon chains-and-vals chain mon.json $NODE_DIRS

# start the netmon in bench mode and fire the transactions
netmon bench mon.json $RESULTS $N_TXS go run transact.go $N_TXS
```





