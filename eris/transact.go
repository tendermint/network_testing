package main

import (
	"bytes"
	"crypto/rand"
	"encoding/hex"
	"flag"
	"fmt"
	mrand "math/rand"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"sync"
	"time"

	ebi "github.com/eris-ltd/eris-abi/core"
	acm "github.com/eris-ltd/eris-db/account"
	types "github.com/eris-ltd/eris-db/txs"
	"github.com/tendermint/go-rpc/client"
	rpctypes "github.com/tendermint/go-rpc/types"
	"github.com/tendermint/go-wire"
)

var contractAddr []byte

var contractAddrHex = flag.String("contract", "4D5F1BB2AED47C6C0F7E1155EE0B91AC34A7BA12", "address of contract") // determinism!
var abiFile = flag.String("abi-file", "/data/tendermint/eris/abi", "path to abi file")
var chainID = flag.String("chainID", "eris-chain", "chain id")
var readProp = flag.Float64("read-prop", 0.1, "percentage of txs which should be reads")
var startAccount = flag.Int("start-acc", 0, "account index to start sending txs from")
var nAccounts = flag.Int("n-acc", 10, "number of accounts to use to send txs")

func main() {
	flag.Parse()
	args := flag.Args()
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

	if *contractAddrHex == "" {
		fmt.Println("Must specify a contract address for eris txs")
		os.Exit(1)
	}
	contractAddr, err = hex.DecodeString(*contractAddrHex)
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}

	// generate keys deterministically
	privAccs := []*acm.PrivAccount{}
	for i := *startAccount; i < (*startAccount + *nAccounts); i++ {
		privAccs = append(privAccs, acm.GenPrivAccountFromSecret(fmt.Sprintf("%d", i)))
	}

	wg := new(sync.WaitGroup)
	wg.Add(len(hosts))
	start := time.Now()
	fmt.Printf("Sending %d txs on every host %v\n", nTxs, hosts)
	nonceMap := make(map[string]int)
	for thisHostI, thisHost := range hosts {
		hostIndex := thisHostI + 1 // plus one because machine names are 1-based
		go broadcastTxsToHost(wg, errCh, hostIndex, thisHost, nTxs, machPrefix, 0, privAccs, nonceMap)
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
	return strings.TrimSpace(buf.String())
}

func broadcastTxsToHost(wg *sync.WaitGroup, errCh chan error, valI int, valHost string, nTxs int, machPrefix string, txCount int, privAccs []*acm.PrivAccount, nonceMap map[string]int) {
	reconnectSleepSeconds := time.Second * 1

	// can handle disconnects with nonceMap by loading from rpc every time.
	// for now assume nodes dont crash and ws is perfect and nonces start at 0

	// thisStart := time.Now()
	// cli := rpcclient.NewClientURI(valHost + ":46657")
	fmt.Println("Connecting to host to broadcast txs", machPrefix, valI, valHost)
	cli := rpcclient.NewWSClient(valHost, "/websocket")
	if _, err := cli.Start(); err != nil {
		if nTxs == 0 {
			time.Sleep(reconnectSleepSeconds)
			broadcastTxsToHost(wg, errCh, valI, valHost, nTxs, machPrefix, txCount, privAccs, nonceMap)
			return
		}
		fmt.Printf("Error starting websocket connection to val%d (%s): %v\n", valI, valHost, err)
		os.Exit(1)
	}

	reconnect := make(chan struct{})
	go func(count int) {
		ticker := time.NewTicker(reconnectSleepSeconds)
	LOOP:
		for {
			select {
			case <-cli.ResultsCh:
				count += 1
				// nTxs == 0 means just loop forever
				if nTxs > 0 && count == nTxs {
					break LOOP
				}
			case err := <-cli.ErrorsCh:
				fmt.Println("err: val", valI, valHost, err)
			case <-cli.Quit:
				broadcastTxsToHost(wg, errCh, valI, valHost, nTxs, machPrefix, count, privAccs, nonceMap)
				return
			case <-reconnect:
				broadcastTxsToHost(wg, errCh, valI, valHost, nTxs, machPrefix, count, privAccs, nonceMap)
				return
			case <-ticker.C:
				if nTxs == 0 {
					cli.Stop()
					broadcastTxsToHost(wg, errCh, valI, valHost, nTxs, machPrefix, count, privAccs, nonceMap)
					return
				}
			}
		}
		fmt.Printf("Received all responses from %s%d (%s)\n", machPrefix, valI, valHost)
		wg.Done()
	}(txCount)
	var i = 0
	for {
		/*		if i%(nTxs/4) == 0 {
				fmt.Printf("Have sent %d txs to %s%d. Total time so far: %v\n", i, machPrefix, valI, time.Since(thisStart))
			}*/

		if !cli.IsRunning() {
			return
		}

		key := make([]byte, 32)
		value := make([]byte, 32)
		if _, err := rand.Read(key); err != nil {
			fmt.Println(err)
			os.Exit(1)
		}
		if _, err := rand.Read(value); err != nil {
			fmt.Println(err)
			os.Exit(1)
		}

		var txDataHex string
		var err error

		u := mrand.Float64()
		if u < *readProp {
			txDataHex, err = ebi.FilePack(*abiFile, []string{"get", string(key)}...)
		} else {
			txDataHex, err = ebi.FilePack(*abiFile, []string{"set", string(key), string(value)}...)
		}
		if err != nil {
			fmt.Println(err)
			os.Exit(1)
		}

		txData, err := hex.DecodeString(txDataHex)
		if err != nil {
			fmt.Println(err)
			os.Exit(1)
		}

		privI := mrand.Intn(len(privAccs))
		privAcc := privAccs[privI]
		nonce := nonceMap[string(privAcc.Address)] + 1
		tx := types.NewCallTxWithNonce(privAcc.PubKey, contractAddr, txData, 1, 10000, 0, nonce)
		tx.Sign(*chainID, privAcc)
		nonceMap[string(privAcc.Address)] = nonce
		txBytes := wire.BinaryBytes(struct{ types.Tx }{tx})

		if err := cli.WriteJSON(rpctypes.RPCRequest{
			JSONRPC: "2.0",
			ID:      "",
			Method:  "broadcast_tx_async",
			Params:  []interface{}{hex.EncodeToString(txBytes)},
		}); err != nil {
			fmt.Printf("Error sending tx %d to validator %d: %v. Attempt reconnect\n", i, valI, err)
			reconnect <- struct{}{}
			return
		}
		i += 1
		if nTxs > 0 && i >= nTxs {
			break
		} else if nTxs == 0 {
			time.Sleep(time.Millisecond * 1)
		}
	}
	fmt.Printf("Done sending %d txs to %s%d (%s)\n", nTxs, machPrefix, valI, valHost)
}
