#! /bin/bash

function ifExit(){
	ecode=$?
	if [[ "$ecode" != "0" ]]; then
		echo "$ecode : $1"
		exit 1
	fi
}

BLOCKSIZE=$1
TXSIZE=$2 # tx size
N_TXS=$3 # number of transactions per validator
MACH_PREFIX=$4 # machine name prefix
RESULTS=$5

echo "####################################" 
echo "Experiment!"
echo "Block size: $BLOCKSIZE"
echo "Tx size: $TXSIZE"
echo "Machine prefix: $MACH_PREFIX"
echo ""

APP_HASH=0x400ACFCD5A1156D2F9CB4887847BC67DFDA734EE #deterministic
export PROXY_APP_INIT_FILE=eris/init_erisdb.sh


NODE_DIRS=${MACH_PREFIX}_data
LOCAL_NODE=true bash eris/start.sh $MACH_PREFIX 1 $NODE_DIRS $APP_HASH

echo "started node"

sleep 5

echo "activate mempool"
# activate mempool
curl http://localhost:46657/unsafe_set_config?type=\"int\"\&key=\"block_size\"\&value=\"100\" #> /dev/null &

echo "status"
curl http://localhost:46657/status

echo "deploy"

# deploy the contract (contract address is deterministic)
go run eris/deploy.go -host localhost eris/getset.evm

# let it commit
sleep 3

echo "deactivate mem"

# deactivate mempool
curl -s localhost:46657/unsafe_set_config?type=\"int\"\&key=\"block_size\"\&value=\"-1\" #> /dev/null &

echo "start tx player"

# start the tx player on each node
go run eris/transact.go -abi-file eris/getset.abi -start-acc 1 -n-acc 1 $N_TXS local

echo "Wait for transactions to load"
done_cum=0
for t in `seq 1 100`; do
	n=`curl -s localhost:46657/num_unconfirmed_txs | jq .result[1].n_txs`
	if [[ "$n" -ge "$N_TXS" ]]; then
		break
	else
		echo "val $i only has $n txs in mempool"
	fi
	sleep 1
done
echo "All transactions loaded. Waiting for a block."

# wait for a block
while true; do
	blockheightStart=`curl -s localhost:46657/status | jq .result[1].latest_block_height`
	if [[ "$blockheightStart" != "0" ]]; then
		echo "Block height $blockheightStart"
		break
	fi
	sleep 1
done

# activate mempool
curl -s localhost:46657/unsafe_set_config?type=\"int\"\&key=\"block_size\"\&value=\"$BLOCKSIZE\" 
