#! /bin/bash
# eg. `./setup.sh single 8 10000 250 1000000 mach results/single/8`

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
	if [[ $? != 0 ]]; then
		echo "launch failed"
		exit 1
	fi
fi
n=$(docker-machine ls | grep $MACH_PREFIX | wc -l)
if (("$n" < "$N")); then
	echo "Launched machines but do not have enough for the tests. Did docker-machine fail?"
	exit 2
fi

# create node data and start all nodes
NODE_DIRS=${MACH_PREFIX}_data
bash test_raw/start.sh $MACH_PREFIX $N $NODE_DIRS $BLOCKSIZE

echo "All nodes started. Load up transactions"

go run utils/transact.go $N_TXS $MACH_PREFIX $N

echo "Waiting for a block"

# wait for a block
DONE=false
while [[ "$DONE" != "true" ]]
do
	n=`curl -s $(docker-machine ip ${MACH_PREFIX}1):46657/status | jq .result[1].latest_block_height`
	if [[ "$n" != "0" ]]; then
		DONE=true
		echo "Block height $n"
	fi
	sleep 1
done

echo "Wait a few seconds for vals to sync up"

# wait a few seconds for all vals to sync
sleep 5

echo "Activate mempools!"

# activate mempools
for i in `seq 1 $N`; do
	curl -s $(docker-machine ip ${MACH_PREFIX}$i):46657/test_start_mempool > /dev/null &
done

echo "Wait for mempools to clear"

#wait to clear all txs
DONE=false
while [[ "$DONE" != "true" ]]
do
	done_cum=0
	for i in `seq 1 $N`; do
		n=`curl -s $(docker-machine ip ${MACH_PREFIX}$i):46657/unconfirmed_txs | jq .result[1].n_txs`
		if [[ "$n" == "0" ]]; then
			done_cum=$((done_cum+1))
		fi
	done
	if [[ "$done_cum" == "$N" ]]; then
		DONE=true
	fi
done

# stop the nodes
mintnet docker --machines "$MACH_PREFIX[1-${N}]" -- stop bench_app_tmnode

bash test_raw/analysis.sh $MACH_PREFIX $N $N_TXS $RESULTS

