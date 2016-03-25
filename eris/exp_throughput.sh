#! /bin/bash

function ifExit(){
	ecode=$?
	if [[ "$ecode" != "0" ]]; then
		echo "$ecode : $1"
		exit 1
	fi
}

DATACENTERS=$1 # single or multi
N=$2 # number of nodes
BLOCKSIZE=$3 # block size (n txs)
TXSIZE=$4 # tx size
N_TXS=$5 # number of transactions per validator
MACH_PREFIX=$6 # machine name prefix
RESULTS=$7

echo "####################################" 
echo "Experiment!"
echo "Nodes: $N"
echo "Block size: $BLOCKSIZE"
echo "Tx size: $TXSIZE"
echo "Machine prefix: $MACH_PREFIX"
echo ""

APP_HASH=0x400ACFCD5A1156D2F9CB4887847BC67DFDA734EE #deterministic
export PROXY_APP_INIT_FILE=eris/init_erisdb.sh


NODE_DIRS=${MACH_PREFIX}_data
bash eris/launch.sh $DATACENTERS $N $MACH_PREFIX $NODE_DIRS $APP_HASH

sleep 2

# activate mempools
for i in `seq 1 $N`; do
	curl -s $(docker-machine ip ${MACH_PREFIX}$i):46657/unsafe_set_config?type=\"int\"\&key=\"block_size\"\&value=\"100\" #> /dev/null &
done

# deploy the contract (contract address is deterministic)
go run eris/deploy.go -host $(docker-machine ip benchik1) eris/getset.evm

# let it commit
sleep 5

# deactivate mempools
for i in `seq 1 $N`; do
	curl -s $(docker-machine ip ${MACH_PREFIX}$i):46657/unsafe_set_config?type=\"int\"\&key=\"block_size\"\&value=\"-1\" #> /dev/null &
done

# start the tx player on each node
go run eris/transact_concurrent.go $MACH_PREFIX $N $N_TXS

export GO15VENDOREXPERIMENT=0 
#go run utils/transact.go $N_TXS $MACH_PREFIX $N
#ifExit "failed to send transactions"

# TODO: ensure they're all at some height (?)

#export NET_TEST_PROF=/data/tendermint/core
if [[ "$NET_TEST_PROF" != "" ]]; then
	# start cpu profilers and snap a heap profile
	for i in `seq 1 $N`; do
		curl -s $(docker-machine ip ${MACH_PREFIX}$i):46657/unsafe_start_cpu_profiler?filename=\"$NET_TEST_PROF/cpu.prof\"
		curl -s $(docker-machine ip ${MACH_PREFIX}$i):46657/unsafe_write_heap_profile?filename=\"$NET_TEST_PROF/mem_start.prof\"
	done
fi


echo "Wait for transactions to load"
done_cum=0
for t in `seq 1 100`; do
	for i in `seq 1 $N`; do
		n=`curl -s $(docker-machine ip ${MACH_PREFIX}$i):46657/num_unconfirmed_txs | jq .result[1].n_txs`
		if [[ "$n" -ge "$N_TXS" ]]; then
			done_cum=$((done_cum+1))
		else
			echo "val $i only has $n txs in mempool"
		fi
	done
	if [[ "$done_cum" == "$N" ]]; then
		break
	fi
	sleep 1
done
if [[ "$done_cum" != "$N" ]]; then
	echo "transactions took too long to load!"
	exit 1
fi
echo "All transactions loaded. Waiting for a block."

# wait for a block
while true; do
	blockheightStart=`curl -s $(docker-machine ip ${MACH_PREFIX}1):46657/status | jq .result[1].latest_block_height`
	if [[ "$blockheightStart" != "0" ]]; then
		echo "Block height $blockheightStart"
		break
	fi
	sleep 1
done

# wait a few seconds for all vals to sync
echo "Wait a few seconds to let validators sync"
sleep 2


# activate mempools
for i in `seq 1 $N`; do
	curl -s $(docker-machine ip ${MACH_PREFIX}$i):46657/unsafe_set_config?type=\"int\"\&key=\"block_size\"\&value=\"$BLOCKSIZE\" &
done

# massage the config file
echo "{}" > mon.json
netmon chains-and-vals chain mon.json $NODE_DIRS

# start the netmon in bench mode 
mkdir -p $RESULTS
netmon bench --n_blocks=16 mon.json $RESULTS 


if [[ "$NET_TEST_PROF" != "" ]]; then
	# stop cpu profilers and snap a heap profile
	for i in `seq 1 $N`; do
		curl -s $(docker-machine ip ${MACH_PREFIX}$i):46657/unsafe_stop_cpu_profiler
		curl -s $(docker-machine ip ${MACH_PREFIX}$i):46657/unsafe_write_heap_profile?filename=\"$NET_TEST_PROF/mem_end.prof\"
	done
fi


