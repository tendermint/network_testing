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

# fix up perms
docker run --rm --volumes-from proxy_tmcommon -u root tendermint/tmbase chown -R tmuser:tmuser /data/tendermint

# start the proxy
docker run -d -p 46657:46657 --name proxy_tmnode --volumes-from proxy_tmcommon -e TMNAME=$NAME -e TMSEEDS=$TMSEEDS -e TMROOT=/data/tendermint/core -e PROXYAPP=nilapp -e TMLOG=info tendermint/tmbase /data/tendermint/core/init.sh

# give it time to catchup
sleep 20
