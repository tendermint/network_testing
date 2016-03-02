#! /bin/bash
# eg. `./setup.sh single 8 10000 250 1000000 mach results/single/8`

DATACENTERS=$1 # single or multi
N=$2 # number of nodes
BLOCKSIZE=$3 # block size (n txs)
TXSIZE=$4 # tx size
N_TXS=$5 # number of transactions
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
bash test_raw/start.sh $MACH_PREFIX $N $NODE_DIRS $BLOCKSIZE $N_TXS $RESULTS

echo "All nodes started. Waiting for a block"

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
	curl $(docker-machine ip ${MACH_PREFIX}$i):46657/test_start_mempool &
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
mintnet stop --machines "$MACH_PREFIX[1-${N}]"

# grab their cswals so we can get commit times
mintnet docker --machines "$MACH_PREFIX[1-${N}]" -- cp bench_app_tmnode:/data/tendermint/core/data/cswal cswal
for i in `seq 1 $N`; do
	mkdir -p $RESULTS/$i
	docker-machine scp ${MACH_PREFIX}$i:cswal $RESULTS/$i/cswal
done

# grab the chain data for one so we can double check which blocks to use
docker-machine ssh ${MACH_PREFIX}1 rm -rf tendermint_data # clear any lingering first
docker-machine ssh ${MACH_PREFIX}1 docker cp bench_app_tmnode:/data/tendermint/core/data tendermint_data
docker-machine scp -r ${MACH_PREFIX}1:tendermint_data $RESULTS/blockchain

blocks=$(go run utils/block_nums.go $RESULTS/blockchain $N_TXS)
startHeight=$(echo $blocks | awk '{print $1}')
endHeight=$(echo $blocks | awk '{print $2}')

echo $blocks
echo $startHeight
echo $endHeight

go run utils/analysis.go $RESULTS $N $N_TXS $startHeight $endHeight
