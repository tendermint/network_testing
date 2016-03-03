MACH_PREFIX=$1
N=$2
N_TXS=$3
RESULTS=$4

## grab their cswals so we can get commit times
#mintnet docker --machines "$MACH_PREFIX[1-${N}]" -- cp bench_app_tmnode:/data/tendermint/core/data/cswal cswal
#for i in `seq 1 $N`; do
#	mkdir -p $RESULTS/$i
#	docker-machine scp ${MACH_PREFIX}$i:cswal $RESULTS/$i/cswal
#done
#
## grab the chain data for one so we can double check which blocks to use
#docker-machine ssh ${MACH_PREFIX}1 rm -rf tendermint_data # clear any lingering first
#docker-machine ssh ${MACH_PREFIX}1 docker cp bench_app_tmnode:/data/tendermint/core/data tendermint_data
#docker-machine scp -r ${MACH_PREFIX}1:tendermint_data $RESULTS/blockchain



txsAndBlocks=$(go run utils/block_nums.go $RESULTS/blockchain)
nTxs=$(echo $txsAndBlocks | awk '{print $1}')
startHeight=$(echo $txsAndBlocks | awk '{print $2}')
endHeight=$(echo $txsAndBlocks | awk '{print $3}')

echo $nTxs
echo $startHeight
echo $endHeight

go run utils/analysis.go $RESULTS $N $nTxs $N_TXS $startHeight $endHeight
