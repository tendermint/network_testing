package main

import (
	"fmt"
	"os"
	"path"

	dbm "github.com/tendermint/go-db"
	bc "github.com/tendermint/tendermint/blockchain"
)

func main() {

	args := os.Args[1:]
	if len(args) < 1 {
		fmt.Println("block_nums.go requires one argument: blockchain_dir")
		os.Exit(1)
	}

	dataDir := args[0]

	blockStoreDB, err := dbm.NewLevelDB(path.Join(dataDir, "blockstore.db"))
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}

	blockStore := bc.NewBlockStore(blockStoreDB)
	height := blockStore.Height()
	var firstBlockWithTxs, lastBlockWithTxs int
	var counter int
	for i := 1; i <= height; i++ {
		blockMeta := blockStore.LoadBlockMeta(i)
		if blockMeta.Header.NumTxs > 0 {
			lastBlockWithTxs = i
			if firstBlockWithTxs == 0 {
				firstBlockWithTxs = i
			}
		}
		counter += blockMeta.Header.NumTxs
	}
	fmt.Println(counter, firstBlockWithTxs, lastBlockWithTxs)
}
