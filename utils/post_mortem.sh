#! /bin/bash

# grab cswals, logs, net_info, consensus_state, ip and region for each machine

MACH_PREFIX=$1
N=$2
RESULTS=$3

# copy out everyones cswal
mintnet docker --machines ${MACH_PREFIX}[1-${N}] -- cp bench_app_tmnode:/data/tendermint/core/data/cswal cswal

# TODO: this concurrently in a go script!
for i in `seq 1 $N`; do
	echo "Collecting artifacts from node $i"
	mkdir -p $RESULTS/$i
	mach=${MACH_PREFIX}$i

	docker-machine inspect $mach | jq .Driver.Region > $RESULTS/$i/region
	docker-machine ip $mach > $RESULTS/$i/ip

	docker-machine scp $mach:cswal $RESULTS/$i/cswal
	docker-machine ssh $mach docker logs bench_app_tmnode &> $RESULTS/$i/tendermint.log
	curl -s $(docker-machine ip $mach):46657/status | jq .result[1] > $RESULTS/$i/status	
	curl -s $(docker-machine ip $mach):46657/net_info | jq .result[1] > $RESULTS/$i/net_info
	curl -s $(docker-machine ip $mach):46657/dump_consensus_state| jq .result[1] > $RESULTS/$i/consensus_state	
done

# finally, copy in the init data (genesis, scripts, priv vals)
cp -r ${MACH_PREFIX}_data $RESULTS/init_data

# NOTE: we don't grab the blockchain or statedbs ...
