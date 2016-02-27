package main

import (
	"encoding/binary"
	"encoding/hex"
	"fmt"
	"os"
	"strconv"

	"github.com/tendermint/go-rpc/client"
	ctypes "github.com/tendermint/tendermint/rpc/core/types"
)

func main() {
	args := os.Args[1:]
	if len(args) < 1 {
		fmt.Println("transact.go expects an argument (ntxs)")
		os.Exit(1)
	}

	nTxS := args[0]
	nTxs, err := strconv.Atoi(nTxS)
	if err != nil {
		fmt.Println("ntxs must be an integer:", err)
		os.Exit(1)
	}

	cli := rpcclient.NewClientURI("localhost:46657")
	params := map[string]interface{}{}
	var result ctypes.TMResult
	for i := 0; i < nTxs; i++ {
		tx := make([]byte, 250)
		binary.PutUvarint(tx, uint64(i))
		params["tx"] = hex.EncodeToString(tx)
		if _, err := cli.Call("broadcast_tx_sync", params, &result); err != nil {
			fmt.Println("Error sending tx:", err)
			os.Exit(1)
		}
	}
}
