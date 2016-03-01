package main

import (
	"fmt"
	"io/ioutil"
	"os"
	"sort"
	"strconv"
	"strings"
	"time"

	"path"

	"github.com/tendermint/go-wire"
	"github.com/tendermint/tendermint/consensus"
	"github.com/tendermint/tendermint/types"
)

var billion = 1000000000

type timeSlice []time.Time

func (p timeSlice) Len() int {
	return len(p)
}

func (p timeSlice) Less(i, j int) bool {
	return p[i].Before(p[j])
}

func (p timeSlice) Swap(i, j int) {
	p[i], p[j] = p[j], p[i]
}

func main() {
	args := os.Args[1:]
	if len(args) < 5 {
		fmt.Println("transact.go expects five args (datadir, nVals, nTxs, start block, end block)")
		os.Exit(1)
	}

	dataDir, nValsString, nTxsString, startHeightString, endHeightString := args[0], args[1], args[2], args[3], args[4]
	nVals, err := strconv.Atoi(nValsString)
	if err != nil {
		fmt.Println("nVals must be an integer:", err)
		os.Exit(1)
	}
	nTxs, err := strconv.Atoi(nTxsString)
	if err != nil {
		fmt.Println("nTxs must be an integer:", err)
		os.Exit(1)
	}
	startHeight, err := strconv.Atoi(startHeightString)
	if err != nil {
		fmt.Println("startHeight must be an integer:", err)
		os.Exit(1)
	}
	endHeight, err := strconv.Atoi(endHeightString)
	if err != nil {
		fmt.Println("endHeight must be an integer:", err)
		os.Exit(1)
	}

	// list of times for each validator, for each block
	nBlocks := endHeight - startHeight + 1
	valBlockTimes := make([][]time.Time, nBlocks)
	for i := 1; i <= nVals; i++ {
		b, err := ioutil.ReadFile(path.Join(dataDir, fmt.Sprintf("%d", i), "cswal"))
		if err != nil {
			fmt.Println("error reading cswal", err)
			os.Exit(1)
		}

		blockN := 0
		lines := strings.Split(string(b), "\n")
	INNER:
		for _, l := range lines {
			var err error
			var msg consensus.ConsensusLogMessage
			wire.ReadJSON(&msg, []byte(l), &err)
			if err != nil {
				fmt.Printf("Error reading json data: %v", err)
				os.Exit(1)
			}

			m, ok := msg.Msg.(types.EventDataRoundState)
			if !ok {
				continue INNER
			} else if m.Step != consensus.RoundStepCommit.String() {
				continue INNER
			} else if m.Height < startHeight {
				continue INNER
			} else if m.Height > endHeight {
				break INNER
			}
			valBlockTimes[blockN] = append(valBlockTimes[blockN], msg.Time)
			blockN += 1
		}
	}

	twoThirdth := nVals * 2 / 3 // plus one but this is used as an index into a slice

	var latencyCum time.Duration
	var lastBlockTime time.Time
	// now loop through blocks, sort times across validators, grab 2/3th val as official time
	for i := 0; i < nBlocks; i++ {
		sort.Sort(timeSlice(valBlockTimes[i]))
		blockTime := valBlockTimes[i][twoThirdth]
		if i == 0 {
			lastBlockTime = blockTime
			continue
		}
		diff := blockTime.Sub(lastBlockTime)
		latencyCum += diff
		lastBlockTime = blockTime
	}

	latency := float64(latencyCum) / float64(endHeight-startHeight)
	throughput := float64(nTxs) / (float64(latencyCum) / float64(billion))
	fmt.Println("Mean latency", latency/float64(billion))
	fmt.Println("Throughput", throughput)
}
