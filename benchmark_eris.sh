#! /bin/bash

MACH_PREFIX=$1
RESULTS=$2

TX_SIZE=250

BLOCKSIZES=(128 256 512 1024 2048 4096 8192 16384 32768) #65536)
VALSETSIZES=(4 8 16 32 64) #128 256 512 1024)

export PROXY_APP_INIT_FILE=experiments/init_erisdb.sh
export CSWAL_LIGHT=false

# DATACENTER is "multi" or "single"
if [[ "$DATACENTER" == "" ]]; then
	DATACENTER=multi
fi

for valsetsize in "${VALSETSIZES[@]}"; do
	SKIPPED_ALL=true
	for blocksize in "${BLOCKSIZES[@]}"; do
		ntxs=$(($blocksize*4)) # load this many txs on each validator
		resultsDir=$RESULTS/blocksize_${blocksize}/nvals_${valsetsize}
		if [ -d "$resultsDir" ]; then
			# no need to rerun experiments
			continue
	  	fi
		SKIPPED_ALL=false
		mkdir -p $resultsDir
		echo "Running experiment: $resultsDir"
		bash eris/exp_throughput.sh $DATACENTER $valsetsize $blocksize $TX_SIZE $ntxs $MACH_PREFIX $resultsDir > $resultsDir/experiment.log
		if [[ "$?" != 0 ]]; then
			echo "experiment failed. gathering postmortem"
			bash utils/post_mortem.sh $MACH_PREFIX $valsetsize $resultsDir/post_mortem
			exit 1
		fi
	done
	if [[ "$SKIPPED_ALL" == "true" ]]; then
		continue
	fi
	# only clear the nodes if we're changing from one valset size to another
	bash utils/rm.sh $MACH_PREFIX $valsetsize
done


mkdir $RESULTS/final_results

for valsetsize in "${VALSETSIZES[@]}"; do
	for blocksize in "${BLOCKSIZES[@]}"; do
		resultsDir=blocksize_${blocksize}/nvals_${valsetsize}
		finalDir=$RESULTS/final_results/$resultsDir
		mkdir -p $finalDir
		cp $RESULTS/$resultsDir/final_results $finalDir/final_results
	done
done

