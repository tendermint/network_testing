#! /bin/bash

MACH_PREFIX=$1
N=$2
NODE_DIRS=$3
BLOCKSIZE=$4

# initialize directories
mintnet init --machines "${MACH_PREFIX}[1-${N}]" chain --app-hash nil $NODE_DIRS

# drop the config file
cat > $NODE_DIRS/chain_config.toml << EOL
# This is a TOML config file.
# For more information, see https://github.com/toml-lang/toml

proxy_app = "nilapp"
moniker = "anonymous"
node_laddr = "0.0.0.0:46656"
skip_upnp=true
seeds = ""
fast_sync = true
db_backend = "leveldb"
log_level = "notice"
rpc_laddr = "0.0.0.0:46657"

block_size=$BLOCKSIZE
timeout_propose=10000 # we assume for testing everyone is online and the network is co-operative ...
timeout_commit=1 # don't wait for votes on commit; assume synchrony for everything else
mempool_recheck=false # don't care about app state
mempool_reap=false # don't reap txs into blocks until we're all synced 
mempool_broadcast=false # don't broadcast mempool txs
cswal_light=true # don't write block part messages
p2p_send_rate=51200000 # 5 MB/s
p2p_recv_rate=51200000 # 5 MB/s
max_msg_packet_payload_size=65536
EOL

# copy the config file into every dir
for i in `seq 1 $N`; do
		cp $NODE_DIRS/chain_config.toml $NODE_DIRS/${MACH_PREFIX}$i/core/config.toml
done

# overwrite the init file so we can pick tendermint branch
cat > $NODE_DIRS/core/init.sh << EOL
#! /bin/bash
TMREPO="github.com/tendermint/tendermint"
BRANCH="params"

go get -d \$TMREPO/cmd/tendermint
cd \$GOPATH/src/\$TMREPO
git fetch origin \$BRANCH
git checkout \$BRANCH
glide install
go install ./cmd/tendermint

tendermint node --seeds="\$TMSEEDS" --moniker="\$TMNAME" --proxy_app="nilapp" 
EOL

# start the nodes
mintnet start --machines "$MACH_PREFIX[1-${N}]" --no-tmsp bench_app $NODE_DIRS
