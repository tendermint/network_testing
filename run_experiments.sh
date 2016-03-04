

MACH_PREFIX=$1
RESULTS=$2

TX_SIZE=250

BLOCKSIZES=(100 1000 10000)
#VALSETSIZES=(4 8 16 32 64 128 256 512 1024)
VALSETSIZES=(4 8) #16 32) #64 128 256 512 1024)

for valsetsize in "${VALSETSIZES[@]}"; do
	for blocksize in "${BLOCKSIZES[@]}"; do
		ntxs=$(($blocksize*4))
		resultsDir=$RESULTS/blocksize_${blocksize}/nvals_${valsetsize}
		if [ -d "$resultsDir" ]; then
			# no need to rerun experiments
			continue
	  	fi
		mkdir -p $resultsDir
		echo "Running experiment: $resultsDir"
		bash test_raw/experiment_raw.sh multi $valsetsize $blocksize $TX_SIZE $ntxs $MACH_PREFIX $resultsDir > $resultsDir/experiment.log
		bash utils/rm.sh $MACH_PREFIX $valsetsize
	done
done
