MACH_PREFIX=$1
N=$2
N_TXS=$3
RESULTS=$4

# grab stuff that needs the nodes online first, for forensics
for i in `seq 1 $N`; do
	mkdir -p $RESULTS/$i
	mach=${MACH_PREFIX}$i
	curl -s $(docker-machine ip $mach):46657/status | jq .result[1] > $RESULTS/$i/status	
	curl -s $(docker-machine ip $mach):46657/net_info | jq .result[1] > $RESULTS/$i/net_info
	curl -s $(docker-machine ip $mach):46657/dump_consensus_state| jq .result[1] > $RESULTS/$i/consensus_state	
done

mintnet stop --machines "$MACH_PREFIX[1-${N}]" bench_app

## grab their cswals so we can get commit times, and the logs for forensics
mintnet docker --machines "$MACH_PREFIX[1-${N}]" -- cp bench_app_tmnode:/data/tendermint/core/data/cswal cswal
for i in `seq 1 $N`; do
	mkdir -p $RESULTS/$i
	mach=${MACH_PREFIX}$i
	docker-machine scp $mach:cswal $RESULTS/$i/cswal

	docker-machine inspect $mach | jq .Driver.Region > $RESULTS/$i/region
	docker-machine ip $mach > $RESULTS/$i/ip
	docker-machine ssh $mach docker logs bench_app_tmnode &> $RESULTS/$i/tendermint.log
done

# copy in the init data (genesis, scripts, priv vals)
cp -r ${MACH_PREFIX}_data $RESULTS/init_data

# grab the chain data for one so we can double check which blocks to use
docker-machine ssh ${MACH_PREFIX}1 rm -rf tendermint_data # clear any lingering first
docker-machine ssh ${MACH_PREFIX}1 docker cp bench_app_tmnode:/data/tendermint/core/data tendermint_data
docker-machine scp -r ${MACH_PREFIX}1:tendermint_data $RESULTS/blockchain

export GO15VENDOREXPERIMENT=0 
txsAndBlocks=$(go run utils/block_nums.go $RESULTS/blockchain)
nTxs=$(echo $txsAndBlocks | awk '{print $1}')
startHeight=$(echo $txsAndBlocks | awk '{print $2}')
endHeight=$(echo $txsAndBlocks | awk '{print $3}')

echo $nTxs
echo $startHeight
echo $endHeight
expectedTxs=$(($N_TXS*N))
echo $expectedTxs
go run utils/analysis.go $RESULTS $N $nTxs $expectedTxs $startHeight $endHeight
