MACH_PREFIX=$1
N=$2
N_TXS=$3
startBlock=$4
endBlock=$5
RESULTS=$6

echo "Fetch latest status, net_info, consensus_state from each node"
# grab stuff that needs the nodes online first, for forensics
for i in `seq 1 $N`; do
	# TODO: in parallel from a go script!
	mkdir -p $RESULTS/$i
	mach=${MACH_PREFIX}$i
	curl -s $(docker-machine ip $mach):46657/status | jq .result[1] > $RESULTS/$i/status	
	curl -s $(docker-machine ip $mach):46657/net_info | jq .result[1] > $RESULTS/$i/net_info
	curl -s $(docker-machine ip $mach):46657/dump_consensus_state| jq .result[1] > $RESULTS/$i/consensus_state	
done

echo "Get exact block nums with txs"
# get the exact block nums with txs
mach1ip=$(docker-machine ip ${MACH_PREFIX}1):46657
export GO15VENDOREXPERIMENT=0 
txsAndBlocks=$(go run utils/block_nums_rpc.go $startBlock $endBlock $mach1ip)
#txsAndBlocks=$(go run utils/block_nums.go $RESULTS/blockchain)
nTxs=$(echo $txsAndBlocks | awk '{print $1}')
startHeight=$(echo $txsAndBlocks | awk '{print $2}')
endHeight=$(echo $txsAndBlocks | awk '{print $3}')

echo $nTxs
echo $startHeight
echo $endHeight

# we stop all but one, its often convenient, specially for inspecting profiles
mintnet stop --machines "$MACH_PREFIX[2-${N}]" bench_app

## grab their cswals so we can get commit times, and the logs for forensics
mintnet docker --machines "$MACH_PREFIX[1-${N}]" -- cp bench_app_tmnode:/data/tendermint/core/data/cswal cswal
go run utils/collect_logs.go $MACH_PREFIX $RESULTS $N

if [[ "$NET_TEST_PROF" != "" ]]; then
	# copy profs and binaries out of docker containers
	# XXX MACH_PREFIX ?!
	docker-machine ssh docker cp bench_app_tmnode:$NET_TEST_PROF/cpu.prof cpu.prof
	docker-machine ssh docker cp bench_app_tmnode:$NET_TEST_PROF/mem_start.prof mem_start.prof
	docker-machine ssh docker cp bench_app_tmnode:$NET_TEST_PROF/mem_end.prof mem_end.prof
	docker-machine ssh docker cp bench_app_tmnode:/go/bin/mintbench mintbench

	# and onto local machine
	mkdir -p $RESULTS/1
	mach=${MACH_PREFIX}1
	docker-machine scp $mach:*.prof $RESULTS/1/
	docker-machine scp $mach:mintbench $RESULTS/1/mintbench.bin
fi

# copy in the init data (genesis, scripts, priv vals)
cp -r ${MACH_PREFIX}_data $RESULTS/init_data

# replaced by querying rpc
# grab the chain data for one so we can double check which blocks to use
#docker-machine ssh ${MACH_PREFIX}1 rm -rf tendermint_data \
#	\&\& docker cp bench_app_tmnode:/data/tendermint/core/data tendermint_data \
#	\&\& tar -czvf tendermint_data.tar.gz tendermint_data
#docker-machine scp -r ${MACH_PREFIX}1:tendermint_data.tar.gz $RESULTS/blockchain.tar.gz && tar -xzvf $RESULTS/blockchain.tar.gz -C $RESULTS/ && mv $RESULTS/tendermint_data $RESULTS/blockchain

// TODO: deal with new N_TX total mechanisms...
expectedTxs=$(($N_TXS*N))
echo $expectedTxs
go run utils/analysis.go $RESULTS $N $nTxs $expectedTxs $startHeight $endHeight
