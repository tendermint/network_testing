#! /bin/bash
# eg. `./setup.sh single 8 10000 250 1000000 mach results/single/8`

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

# make sure we have enough nodes
n=$(docker-machine ls | grep $MACH_PREFIX | wc -l)
if (("$n" < "$N")); then
	# launch the nodes
	bash utils/launch.sh $MACH_PREFIX $DATACENTERS $(($n+1)) $N
	ifExit "launch failed"
fi
n=$(docker-machine ls | grep $MACH_PREFIX | wc -l)
if (("$n" < "$N")); then
	echo "Launched machines but do not have enough for the tests. Did docker-machine fail?"
	exit 2
fi

# create node data and start all nodes
NODE_DIRS=${MACH_PREFIX}_data
bash test_raw/start.sh $MACH_PREFIX $N $NODE_DIRS $N_TXS
ifExit "failed to start tendermint"

echo "All nodes started"

export GO15VENDOREXPERIMENT=0 
#go run utils/transact.go $N_TXS $MACH_PREFIX $N
#ifExit "failed to send transactions"

echo "Wait for transactions to load"
done_cum=0
for t in `seq 1 100`; do
	for i in `seq 1 $N`; do
		n=`curl -s $(docker-machine ip ${MACH_PREFIX}$i):46657/num_unconfirmed_txs | jq .result[1].n_txs`
		if [[ "$n" == "$N_TXS" ]]; then
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
sleep 5

# TODO: ensure they're all at some height (?)

#export NET_TEST_PROF=/data/tendermint/core/tendermint.prof
if [[ "$NET_TEST_PROF" != "" ]]; then
	# start cpu profilers and snap a heap profile
	for i in `seq 1 $N`; do
		curl -s $(docker-machine ip ${MACH_PREFIX}$i):46657/unsafe_start_cpu_profiler?filename=\"$NET_TEST_PROF/cpu.prof\"
		curl -s $(docker-machine ip ${MACH_PREFIX}$i):46657/unsafe_write_heap_profile?filename=\"$NET_TEST_PROF/mem_start.prof\"
	done
fi

echo "Activate mempools by increasing block_size to $BLOCKSIZE!"

# activate mempools
for i in `seq 1 $N`; do
	curl -s $(docker-machine ip ${MACH_PREFIX}$i):46657/unsafe_set_config?type=\"int\"\&key=\"block_size\"\&value=\"$BLOCKSIZE\" &
done

if [[ "$CRASH_FAILURES" != "" ]]; then
	# start a process that kills and restarts a random node every second
	go run utils/crasher.go $MACH_PREFIX $N bench_app_tmnode &
	CRASHER_PROC=$!
fi

echo "Wait for mempools to clear"

#wait to clear all txs
DONE=false
while [[ "$DONE" != "true" ]]
do
	done_cum=0
	for i in `seq 1 $N`; do
		n=`curl -s $(docker-machine ip ${MACH_PREFIX}$i):46657/num_unconfirmed_txs | jq .result[1].n_txs`
		if [[ "$n" == "0" ]]; then
			done_cum=$((done_cum+1))
		else
			echo "val $i still has $n txs in mempool"
		fi
	done
	if [[ "$done_cum" == "$N" ]]; then
		DONE=true
	fi
done
echo "All mempools cleared"

# stop the crasher
if [[ "$CRASH_FAILURES" != "" ]]; then
	# must make sure all nodes are still on!
	kill -9 $CRASHER_PROC
fi


blockheightEnd=`curl -s $(docker-machine ip ${MACH_PREFIX}1):46657/status | jq .result[1].latest_block_height`
echo "Block $blockheightEnd"

if [[ "$NET_TEST_PROF" != "" ]]; then
	# stop cpu profilers and snap a heap profile
	for i in `seq 1 $N`; do
		curl -s $(docker-machine ip ${MACH_PREFIX}$i):46657/unsafe_stop_cpu_profiler
		curl -s $(docker-machine ip ${MACH_PREFIX}$i):46657/unsafe_write_heap_profile?filename=\"$NET_TEST_PROF/mem_end.prof\"
	done
	# we don't do analysis or stop the nodes so we can hop into the container and check the profile
	#	exit 0
fi


bash test_raw/analysis.sh $MACH_PREFIX $N $N_TXS $blockheightStart $blockheightEnd $RESULTS 

