#! /bin/bash

MACH_PREFIX=$1 # machine name prefix
N=$2 # number of nodes
N_TXS=$3 # number of transactions per validator
BLOCKSIZE=$4 # block size (n txs)
NODE_DIRS=$5
RESULTS=$6

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

bash experiments/raw_analysis.sh $MACH_PREFIX $N $N_TXS $blockheightStart $blockheightEnd $RESULTS 
