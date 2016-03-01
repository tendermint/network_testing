#! /bin/bash
# eg. `./setup.sh single 8 10000 250 1000000 mach results/single/8`


# first arg is "single" or "multi"
if [[ "$1" == "single" ]]; then
	GLOBAL=false
elif [[ "$1" == "multi" ]]; then
	GLOBAL=true
else
	echo "first arg must be `single` or `multi`"
	exit 1
fi

N=$2 # number of nodes
BLOCKSIZE=$3 # block size (n txs)
TXSIZE=$4 # tx size
N_TXS=$5 # number of transactions
MACH_PREFIX=$6 # machine name prefix
RESULTS=$7

# make sure we have enough nodes
n=$(docker-machine ls | grep $MACH_PREFIX | wc -l)
if (("$n" < "$N")); then
	# launch the nodes
	bash launch.sh $MACH_PREFIX $GLOBAL $(($n+1)) $N
	if [[ $? != 0 ]]; then
		echo "launch failed"
		exit 1
	fi
fi
n=$(docker-machine ls | grep $MACH_PREFIX | wc -l)
if (("$n" < "$N")); then
	echo "Launched machines but do not have enough for the tests. Did docker-machine fail?"
	exit 2
fi

NODE_DIRS=${MACH_PREFIX}_data

# make all node data and start the node on every machine 
bash start.sh $MACH_PREFIX $N $NODE_DIRS

# start the local proxy
bash proxy.sh $MACH_PREFIX $N $NODE_DIRS

# massage the config file
echo "{}" > mon.json
netmon chains-and-vals chain mon.json $NODE_DIRS

# start the netmon in bench mode and fire the transactions
mkdir -p $RESULTS
netmon bench mon.json $RESULTS $N_TXS go run transact.go $N_TXS

# once the txs all get committed, the netmon process will finish.
# locally timestamped blocks get spat to stdout, and a results summary gets written to file

