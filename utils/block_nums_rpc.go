package main

import (
	"fmt"
	"os"
	"strconv"

	rpcclient "github.com/tendermint/go-rpc/client"
	ctypes "github.com/tendermint/tendermint/rpc/core/types"
)

func main() {

	args := os.Args[1:]
	if len(args) < 3 {
		fmt.Println("block_nums_rpc.go requires three arguments: startHeight, endHeight, ipAddr")
		os.Exit(1)
	}

	startNstring, endNstring, ipAddr := args[0], args[1], args[2]

	startN, err := strconv.Atoi(startNstring)
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
	endN, err := strconv.Atoi(endNstring)
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}

	var result ctypes.TMResult
	client := rpcclient.NewClientURI(ipAddr)
	_, err = client.Call("blockchain", map[string]interface{}{"minHeight": startN, "maxHeight": endN}, &result)
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
	blockMetas := result.(*ctypes.ResultBlockchainInfo).BlockMetas

	var firstBlockWithTxs, lastBlockWithTxs int
	var counter int
	// NOTE: blockMetas are ordered by highest height first
	for i, blockMeta := range blockMetas {
		if blockMeta.Header.NumTxs > 0 {
			firstBlockWithTxs = endN - i
			if lastBlockWithTxs == 0 {
				lastBlockWithTxs = endN - i
			}
		}
		counter += blockMeta.Header.NumTxs
	}
	fmt.Println(counter, firstBlockWithTxs, lastBlockWithTxs)

}
