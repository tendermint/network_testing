package main

import (
	"fmt"
	"os"
	"path"
	"strconv"

	dbm "github.com/tendermint/go-db"
	bc "github.com/tendermint/tendermint/blockchain"
)

func main() {

	args := os.Args[1:]
	if len(args) < 2 {
		fmt.Println("block_nums.go requires two arguments: blockchain_dir, n_txs")
		os.Exit(1)
	}

	dataDir, nTxsString := args[0], args[1]
	nTxs, err := strconv.Atoi(nTxsString)
	if err != nil {
		fmt.Println("nTxs must be an integer:", err)
		os.Exit(1)
	}

	blockStoreDB, err := dbm.NewLevelDB(path.Join(dataDir, "blockstore.db"))
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}

	blockStore := bc.NewBlockStore(blockStoreDB)
	height := blockStore.Height()

	var startN, endN int
	var counter int
	for i := 1; i <= height; i++ {
		blockMeta := blockStore.LoadBlockMeta(i)
		if startN == 0 && blockMeta.Header.NumTxs > 0 {
			startN = i
		}
		counter += blockMeta.Header.NumTxs
		if counter >= nTxs {
			endN = i
			break
		}
	}
	fmt.Println(startN, endN)
}
