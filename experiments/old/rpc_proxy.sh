#! /bin/bash

MACH_PREFIX=$1
N=$2
NODE_DIRS=$3

NODE_DIR=$NODE_DIRS/proxy


# copy one of the node dirs 
if [[ ! -d $NODE_DIR ]]; then
	cp -r $NODE_DIRS/${MACH_PREFIX}1 $NODE_DIR
	rm $NODE_DIR/core/priv_validator.json
fi

# drop the config file
cat > $NODE_DIR/core/config.toml << EOL
# This is a TOML config file.
# For more information, see https://github.com/toml-lang/toml

proxy_app = "nilapp"
moniker = "anonymous"
node_laddr = "0.0.0.0:46656"
skip_upnp=true
seeds = ""
fast_sync = true
db_backend = "memdb"
log_level = "info"
rpc_laddr = "0.0.0.0:46657"
prof_laddr = "" 

block_size=-1 # start at -1 so mempool doesn't empty
timeout_propose=10000 # we assume for testing everyone is online and the network is co-operative ...
timeout_commit=1 # don't wait for votes on commit; assume synchrony for everything else
mempool_recheck=false # don't care about app state
cswal_light=true # don't write block part messages
p2p_send_rate=51200000 # 50 MB/s
p2p_recv_rate=51200000 # 50 MB/s
max_msg_packet_payload_size=131072
disable_data_hash=true
EOL

# we connect to four seeds
n=$(($N / 4))
TMSEEDS=""
for i in `seq 1 4`; do
	machN=$(($n*i))
	ip=$(docker-machine ip ${MACH_PREFIX}$machN)
	TMSEEDS="${TMSEEDS},${ip}:46656"
done
TMSEEDS=${TMSEEDS:1} # clip first comma

echo $TMSEEDS

# copy in all the data
docker run --name proxy_tmcommon --entrypoint true tendermint/tmbase
docker cp $NODE_DIRS/data proxy_tmcommon:/data/tendermint/data
docker cp $NODE_DIRS/app proxy_tmcommon:/data/tendermint/app
docker cp $NODE_DIRS/core proxy_tmcommon:/data/tendermint/core
docker cp $NODE_DIR/core/genesis.json proxy_tmcommon:/data/tendermint/core/genesis.json
docker cp $NODE_DIR/core/config.toml proxy_tmcommon:/data/tendermint/core/config.toml

# fix up perms
docker run --rm --volumes-from proxy_tmcommon -u root tendermint/tmbase chown -R tmuser:tmuser /data/tendermint

# start the proxy
docker run -d -p 46657:46657 --name proxy_tmnode --volumes-from proxy_tmcommon -e TMNAME=$NAME -e TMSEEDS=$TMSEEDS -e TMROOT=/data/tendermint/core -e PROXYAPP=nilapp -e TMLOG=info $TM_IMAGE /data/tendermint/core/init.sh

# give it time to catchup
sleep 5
