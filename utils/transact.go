package main

import (
	"crypto/rand"
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
	if len(args) < 2 {
		fmt.Println("transact.go expects at least two arguments (ntxs, local/mach_prefix, nvals)")
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
	if host == "local" {
		machPrefix = "localhost"
		hosts = []string{"localhost:46657"}
	} else {
		machPrefix = host
		if len(args) < 3 {
			fmt.Println("must specify number of validators")
			os.Exit(1)
		}
		nvalS := args[2]
		nVals, err := strconv.Atoi(nValS)
		if err != nil {
			fmt.Println("nvals must be an integer:", err)
			os.Exit(1)
		}
		hosts = make([]string, nVals)
		for i := 0; i < nvals; i++ {
			hosts[i] = machIP(machPrefix, i)
		}
	}

	wg := new(sync.WaitGroup)
	wg.Add(len(hosts))
	start := time.Now()
	for hostIndex, h := range hosts {
		go func() {
			cli := rpcclient.NewClientURI(h + ":46657")
			params := map[string]interface{}{}
			var result ctypes.TMResult
			for i := 0; i < nTxs; i++ {
				if i%10000 == 0 {
					fmt.Printf("Have sent %d txs to %s%d", i, machPrefix, hostIndex)
				}
				tx := make([]byte, 250)
				if _, err := rand.Read(tx[:128]); err != nil {
					fmt.Println("err reading from crypto/rand", err)
					os.Exit(1)
				}
				params["tx"] = hex.EncodeToString(tx)
				if _, err := cli.Call("broadcast_tx_sync", params, &result); err != nil {
					fmt.Println("Error sending tx:", err)
					os.Exit(1)
				}
			}
			wg.Done()
		}()
	}
	wg.Wait()
	fmt.Println("Done broadcasting txs. Took", time.Since(start))
}

func machIP(machPrefix string, n int) string {
	buf := new(bytes.Buffer)
	cmd := exec.Command("docker-machine", "ip", fmt.Sprintf("%s%d", machPrefix, n))
	cmd.Stdout = buf
	if err := cmd.Run(); err != nil {
		panic(err)
	}
	return buf.String()
}
