#! /bin/bash

MACH_PREFIX=$1
RESULTS=$2

TX_SIZE=250

VALSETSIZES=(4) #8 16 32 64) #128 256 512 1024)

# DATACENTER is "multi" or "single"
if [[ "$DATACENTER" == "" ]]; then
	DATACENTER=multi
fi

blocksize=2048
nblocks=50

for valsetsize in "${VALSETSIZES[@]}"; do
	resultsDir=$RESULTS/blocksize_${blocksize}/nvals_${valsetsize}
	if [ -d "$resultsDir" ]; then
		# no need to rerun experiments
		continue
	fi
	mkdir -p $resultsDir
	echo "Running experiment: $resultsDir"
	bash experiments/exp_crash.sh $DATACENTER $valsetsize $blocksize $TX_SIZE $nblocks $MACH_PREFIX $resultsDir > $resultsDir/experiment.log
	if [[ "$?" != 0 ]]; then
		echo "experiment failed. gathering postmortem"
		bash utils/post_mortem.sh $MACH_PREFIX $valsetsize $resultsDir/post_mortem
		exit 1
	fi
	bash utils/rm.sh $MACH_PREFIX $valsetsize
done


mkdir $RESULTS/final_results

for valsetsize in "${VALSETSIZES[@]}"; do
	resultsDir=blocksize_${blocksize}/nvals_${valsetsize}
	finalDir=$RESULTS/final_results/$resultsDir
	mkdir -p $finalDir
	cp $RESULTS/$resultsDir/final_results $finalDir/final_results
done

