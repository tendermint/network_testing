#! /bin/bash

MACH_PREFIX=$1
N=$2
NODE_DIRS=$3
APP_HASH=$4

if [[ "$APP_HASH" == "" ]]; then
	APP_HASH=nil
fi

# initialize directories
mintnet init --machines "${MACH_PREFIX}[1-${N}]" chain --app-hash $APP_HASH $NODE_DIRS

if [[ "$TIMEOUT_PROPOSE" == "" ]]; then
	TIMEOUT_PROPOSE=3000 # ms
fi
if [[ "$BLOCK_SIZE" == "" ]]; then
	# start at 0 so mempool doesn't empty, set manually with unsafe_config
	BLOCK_SIZE=0
fi
if [[ "$CSWAL_LIGHT" == "" ]]; then
	CSWAL_LIGHT=true # don't write block part messages
fi
if [[ "$FUZZ_ENABLE" == "" ]]; then
	FUZZ_ENABLE="false" # dont even bother with fuzzer conn wrapper
fi

# NOTE: if not --no-tmsp, this is overwritten by mintnet ...
PROXY_APP_ADDR="nilapp" # in process nothingness

# drop the config file
cat > $NODE_DIRS/chain_config.toml << EOL
# This is a TOML config file.
# For more information, see https://github.com/toml-lang/toml

proxy_app = "$PROXY_APP_ADDR"
moniker = "anonymous"
node_laddr = "0.0.0.0:46656"
skip_upnp=true
seeds = ""
fast_sync = true
db_backend = "memdb"
log_level = "notice"
rpc_laddr = "0.0.0.0:46657"
prof_laddr = "" 

block_size=$BLOCK_SIZE
timeout_propose=$TIMEOUT_PROPOSE
timeout_commit=1 # don't wait for votes on commit; assume synchrony for everything else
mempool_recheck=false # don't care about app state
mempool_broadcast=false # don't broadcast mempool txs
cswal_light=$CSWAL_LIGHT
max_msg_packet_payload_size=65536 #1048576 
block_part_size=32384 #262144 

[p2p]
send_rate=51200000 # 50 MB/s
recv_rate=51200000 # 50 MB/s
fuzz_enable=$FUZZ_ENABLE
fuzz_mode="delay"
EOL

# copy the config file into every dir
for i in `seq 1 $N`; do
		cp $NODE_DIRS/chain_config.toml $NODE_DIRS/${MACH_PREFIX}$i/core/config.toml
done

# overwrite the mintnet core init file (so we can pick tendermint branch)
cp experiments/init.sh $NODE_DIRS/core/init.sh
if [[ "$TM_IMAGE" == "" ]]; then
	# if we're using an image, just a bare script
	TM_IMAGE="tendermint/tmbase:dev"
	echo "#! /bin/bash" > $NODE_DIRS/core/init.sh
fi
echo "tendermint node --seeds="\$TMSEEDS" --moniker="\$TMNAME" " >> $NODE_DIRS/core/init.sh

tmsp_conditions="--no-tmsp"
# overwrite the app file
if [[ "$PROXY_APP_INIT_FILE" != "" ]]; then
	cp $PROXY_APP_INIT_FILE $NODE_DIRS/app/init.sh
	tmsp_conditions="" # if we have an app file we're using tmsp
fi

# start the nodes
mintnet start --machines "$MACH_PREFIX[1-${N}]" $tmsp_conditions --tmcore-image $TM_IMAGE bench_app $NODE_DIRS
