#! /bin/bash

MACH_PREFIX=$1 # machine name prefix
N=$2 # number of nodes
N_TXS=$3 # number of transactions per validator
BLOCKSIZE=$4 # block size (n txs)
NODE_DIRS=$5
RESULTS=$6

###### go run utils/transact.go $N_TXS $MACH_PREFIX $N 

# start the local proxy
# do we even need a proxy
# bash experiments/rpc_proxy.sh $MACH_PREFIX $N $NODE_DIRS

# massage the config file
echo "{}" > mon.json
netmon chains-and-vals chain mon.json $NODE_DIRS

# start the netmon in bench mode 
mkdir -p $RESULTS
netmon bench mon.json $RESULTS $(($N_TXS*$N)) # 

# once the txs all get committed, the netmon process will finish.
# locally timestamped blocks get spat to stdout, and a results summary gets written to file
# activate mempools

