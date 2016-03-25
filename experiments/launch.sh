#! /bin/bash

function ifExit(){
	ecode=$?
	if [[ "$ecode" != "0" ]]; then
		echo "$ecode : $1"
		exit 1
	fi
}

DATACENTERS=$1 # single or multi
N=$2 # number of nodes
MACH_PREFIX=$3 # machine name prefix
NODE_DIRS=$4
APP_HASH=$5

echo "Checking for machines."
# make sure we have enough nodes
n=$(docker-machine ls | grep $MACH_PREFIX | wc -l)
if (("$n" < "$N")); then
	# launch the nodes
	bash utils/launch.sh $MACH_PREFIX $DATACENTERS $(($n+1)) $N
	ifExit "launch failed"
	n=$(docker-machine ls | grep $MACH_PREFIX | wc -l)
	if (("$n" < "$N")); then
		echo "Launched machines but do not have enough for the tests. Did docker-machine fail?"
		exit 2
	fi
else
	echo "Machines already exist."
fi

# create node data and start all nodes
if [[ ! -d "$NODE_DIRS" ]]; then
	bash experiments/start.sh $MACH_PREFIX $N $NODE_DIRS $APP_HASH
	ifExit "failed to start tendermint"
	echo "All nodes started"
else
	# if node data already exists, do nothing
	echo "Tendermint already started."

	# echo "Restarting nodes."
	# mintnet docker --machines "${MACH_PREFIX}[1-$N]" -- \; docker stop bench_app_tmnode \; docker run --volumes-from bench_app_tmcommon --rm -e TMROOT=/data/tendermint/core tendermint/tmbase:dev tendermint unsafe_reset_all \; docker start bench_app_tmnode
fi

