package main

import (
	"encoding/hex"
	"flag"
	"fmt"
	"io/ioutil"
	"os"

	acm "github.com/eris-ltd/eris-db/account"
	types "github.com/eris-ltd/eris-db/txs" // types
	rpcclient "github.com/tendermint/go-rpc/client"
	"github.com/tendermint/go-wire"
	ctypes "github.com/tendermint/tendermint/rpc/core/types"
)

var chainID = flag.String("chainID", "eris-chain", "chain id")
var host = flag.String("host", "localhost", "host to deploy to")

func main() {
	flag.Parse()
	args := flag.Args()
	if len(args) < 1 {
		fmt.Println("deploy.go expects a file with evm code")
		os.Exit(1)
	}

	fileName := args[0]

	txDataHex, err := ioutil.ReadFile(fileName)
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}

	txDataHexString := string(txDataHex[:len(txDataHex)-1]) // shave off new line
	txData, err := hex.DecodeString(txDataHexString)
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}

	// generate keys deterministically
	privAcc := acm.GenPrivAccountFromSecret(fmt.Sprintf("%d", 0))

	nonce := 1
	tx := types.NewCallTxWithNonce(privAcc.PubKey, []byte{}, txData, 1, 10000, 0, nonce)
	tx.Sign(*chainID, privAcc)

	fmt.Println("Deploying contract tx", tx)
	var result ctypes.TMResult
	cli := rpcclient.NewClientJSONRPC(*host + ":46657")
	_, err = cli.Call("broadcast_tx_sync", []interface{}{wire.BinaryBytes(struct{ types.Tx }{tx})}, &result)
	if err != nil {
		fmt.Println(err, *host, cli)
		os.Exit(1)
	}
	fmt.Println(result)

}
