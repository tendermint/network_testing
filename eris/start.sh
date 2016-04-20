#! /bin/bash

MACH_PREFIX=$1
N=$2
NODE_DIRS=$3
APP_HASH=$4

if [[ "$APP_HASH" == "" ]]; then
	APP_HASH=nil
fi

echo "APP HASH: $APP_HASH"
# initialize directories
mintnet init --machines "${MACH_PREFIX}[1-${N}]" chain --app-hash $APP_HASH $NODE_DIRS

if [[ "$TIMEOUT_PROPOSE" == "" ]]; then
	TIMEOUT_PROPOSE=3000 # ms
fi
if [[ "$BLOCK_SIZE" == "" ]]; then
	# start at -1 so mempool doesn't empty, set manually with unsafe_config
	BLOCK_SIZE=-1
fi
if [[ "$CSWAL_LIGHT" == "" ]]; then
	CSWAL_LIGHT=true # don't write block part messages
fi

PROXY_APP_ADDR="nilapp" # in process nothingness
if [[ "$PROXY_APP_INIT_FILE" != "" ]]; then
	PROXY_APP_ADDR="unix:///data/tendermint/app/app.sock"
fi

echo "PROXY APP INIT FILE $PROXY_APP_INIT_FILE"
echo "PROXY APP ADDR $PROXY_APP_ADDR"

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
mempool_recheck=false # dont recheck mempool txs after a block
mempool_broadcast=false # don't broadcast mempool txs
cswal_light=$CSWAL_LIGHT
p2p_send_rate=51200000 # 50 MB/s
p2p_recv_rate=51200000 # 50 MB/s
max_msg_packet_payload_size=131072
EOL

# copy the config file into every dir
for i in `seq 1 $N`; do
		cp $NODE_DIRS/chain_config.toml $NODE_DIRS/${MACH_PREFIX}$i/core/config.toml
done

# copy in the app genesis file
cp eris/genesis.json $NODE_DIRS/app/genesis.json
cp eris/server_conf.toml $NODE_DIRS/app/server_conf.toml
cp eris/config.toml $NODE_DIRS/app/config.toml

# overwrite the mintnet core init file (so we can pick tendermint branch)
cp experiments/init.sh $NODE_DIRS/core/init.sh
if [[ "$TM_IMAGE" == "" ]]; then
	# if we're using an image, just a bare script
	TM_IMAGE="tendermint/tmbase:dev"
	echo "#! /bin/bash" > $NODE_DIRS/core/init.sh
fi
echo "tendermint node --seeds="\$TMSEEDS" --moniker="\$TMNAME" " >> $NODE_DIRS/core/init.sh

# overwrite the app file
if [[ "$PROXY_APP_INIT_FILE" != "" ]]; then
	cp $PROXY_APP_INIT_FILE $NODE_DIRS/app/init.sh
fi

# start the nodes
if [[ "$LOCAL_NODE" == "" ]]; then
	mintnet start --machines "$MACH_PREFIX[1-${N}]" --no-merkleeyes --tmcore-image $TM_IMAGE bench_app $NODE_DIRS
else
	erisdb eris &> erisdb.log &
	rm -rf eris/data
	export TMROOT=$NODE_DIRS/${MACH_PREFIX}1/core 
	tendermint unsafe_reset_all
	tendermint node > tendermint.log &
fi
