package main

import (
	"bytes"
	"crypto/rand"
	"encoding/binary"
	"encoding/hex"
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/tendermint/go-rpc/client"
	rpctypes "github.com/tendermint/go-rpc/types"
	//	ctypes "github.com/tendermint/tendermint/rpc/core/types"
)

func main() {
	args := os.Args[1:]
	if len(args) < 2 {
		fmt.Println("transact.go expects at least two arguments (ntxs, local/mach_prefix, nvals, blocksize)")
		os.Exit(1)
	}

	nTxS, host := args[0], args[1]
	nTxs, err := strconv.Atoi(nTxS)
	if err != nil {
		fmt.Println("ntxs must be an integer:", err)
		os.Exit(1)
	}

	var hosts []string
	var machPrefix string
	//var blocksize int
	if host == "local" {
		machPrefix = "localhost"
		hosts = []string{"localhost:46657"}
	} else if host == "docker_link" {
		machPrefix = "tmnode"
		hosts = []string{"tmnode:46657"}
	} else {
		machPrefix = host
		if len(args) < 3 {
			fmt.Println("must specify number of validators")
			os.Exit(1)
		}
		nvalS := args[2]
		nVals, err := strconv.Atoi(nvalS)
		if err != nil {
			fmt.Println("nvals must be an integer:", err)
			os.Exit(1)
		}
		hosts = make([]string, nVals)
		for i := 0; i < nVals; i++ {
			hosts[i] = machIP(machPrefix, i+1) + ":46657"
		}
	}

	errCh := make(chan error, 1000)

	wg := new(sync.WaitGroup)
	wg.Add(len(hosts))
	start := time.Now()
	fmt.Printf("Sending %d txs on every host %v\n", nTxs, hosts)
	for thisHostI, thisHost := range hosts {
		hostIndex := thisHostI + 1 // plus one because machine names are 1-based
		go broadcastTxsToHost(wg, errCh, hostIndex, thisHost, nTxs, machPrefix, 0)
	}
	wg.Wait()
	fmt.Println("Done broadcasting txs. Took", time.Since(start))

	/*
		fmt.Println("Activate mempools by increasing block_size to", blocksize)
		for _, h := range hosts {
			var result ctypes.TMResult
			cli := rpcclient.NewClientURI(h)
			params := map[string]interface{}{
				"type":  "int",
				"key":   "block_size",
				"value": fmt.Sprintf("%d", blocksize),
			}
			if _, err := cli.Call("unsafe_set_config", params, &result); err != nil {
				fmt.Println("Error setting config:", err)
				os.Exit(1)
			}
		}*/
}

func machIP(machPrefix string, n int) string {
	buf := new(bytes.Buffer)
	cmd := exec.Command("docker-machine", "ip", fmt.Sprintf("%s%d", machPrefix, n))
	cmd.Stdout = buf
	if err := cmd.Run(); err != nil {
		panic(err)
	}
	return strings.TrimSpace(buf.String())
}

func broadcastTxsToHost(wg *sync.WaitGroup, errCh chan error, valI int, valHost string, nTxs int, machPrefix string, txCount int) {
	thisStart := time.Now()
	// cli := rpcclient.NewClientURI(valHost + ":46657")
	cli := rpcclient.NewWSClient(valHost, "/websocket")
	if _, err := cli.Start(); err != nil {
		fmt.Printf("Error starting websocket connection to val%d (%s): %v\n", valI, valHost, err)
		os.Exit(1)
	}

	reconnect := make(chan struct{})
	go func(count int) {
	LOOP:
		for {
			select {
			case <-cli.ResultsCh:
				count += 1
				if count == nTxs {
					break LOOP
				}
			case err := <-cli.ErrorsCh:
				fmt.Println("err: val", valI, valHost, err)
			case <-cli.Quit:
			case <-reconnect:
				broadcastTxsToHost(wg, errCh, valI, valHost, nTxs, machPrefix, count)
				return
			}
		}
		fmt.Printf("Received all responses from %s%d (%s)\n", machPrefix, valI, valHost)
		wg.Done()
	}(txCount)
	// params := map[string]interface{}{}
	// var result ctypes.TMResult
	for i := txCount; i < nTxs; i++ {
		if i%(nTxs/4) == 0 {
			fmt.Printf("Have sent %d txs to %s%d. Total time so far: %v\n", i, machPrefix, valI, time.Since(thisStart))
		}
		// a tx encodes the validator index, the tx number, and some random junk
		tx := make([]byte, 250)
		binary.PutUvarint(tx[:32], uint64(valI))
		binary.PutUvarint(tx[32:64], uint64(i))
		if _, err := rand.Read(tx[234:]); err != nil {
			fmt.Println("err reading from crypto/rand", err)
			os.Exit(1)
		}
		/*params["tx"] = hex.EncodeToString(tx)
		if _, err := cli.Call("broadcast_tx_async", params, &result); err != nil {
			fmt.Println("Error sending tx:", err)
			os.Exit(1)
		}*/

		if err := cli.WriteJSON(rpctypes.RPCRequest{
			JSONRPC: "2.0",
			ID:      "",
			Method:  "broadcast_tx_async",
			Params:  []interface{}{hex.EncodeToString(tx)},
		}); err != nil {
			fmt.Printf("Error sending tx %d to validator %d: %v. Attempt reconnect\n", i, valI, err)
			reconnect <- struct{}{}
			return
		}
		time.Sleep(time.Microsecond * 1)
	}
	fmt.Printf("Done sending %d txs to %s%d (%s)\n", nTxs, machPrefix, valI, valHost)
}
