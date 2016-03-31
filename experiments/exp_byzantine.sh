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
BLOCK_SIZE=$3 # block size (n txs) 
TXSIZE=$4 # tx size
N_BLOCKS=$5 # number of blocks for the whole experiment
MACH_PREFIX=$6 # machine name prefix
RESULTS=$7

export BLOCK_SIZE # inherited by start.sh

echo "####################################" 
echo "Experiment!"
echo "Nodes: $N"
echo "Block size: $BLOCK_SIZE"
echo "Tx size: $TXSIZE"
echo "Machine prefix: $MACH_PREFIX"
echo ""

NODE_DIRS=${MACH_PREFIX}_data
bash experiments/launch.sh $DATACENTERS $N $MACH_PREFIX $NODE_DIRS

# start the tx player on each node
go run utils/transact_concurrent.go $MACH_PREFIX $N 0

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

# massage the config file
echo "{}" > mon.json
netmon chains-and-vals chain mon.json $NODE_DIRS

echo "Make them byzantine"
# make the first third of them byzantine
N_BYZ=$((($N - 1)/3))
for i in `seq 1 $N_BYZ`; do
	echo "Make validator $i byzantine"
	curl -s $(docker-machine ip ${MACH_PREFIX}$i):46657/unsafe_set_config?type=\"bool\"\&key=\"byzantine\"\&value=\"true\"
done

mkdir -p $RESULTS
# start the netmon in bench mode 
netmon bench --n_blocks=$N_BLOCKS mon.json $RESULTS 

echo "Done benchmark"

if [[ "$NET_TEST_PROF" != "" ]]; then
	# stop cpu profilers and snap a heap profile
	for i in `seq 1 $N`; do
		curl -s $(docker-machine ip ${MACH_PREFIX}$i):46657/unsafe_stop_cpu_profiler
		curl -s $(docker-machine ip ${MACH_PREFIX}$i):46657/unsafe_write_heap_profile?filename=\"$NET_TEST_PROF/mem_end.prof\"
	done
fi
