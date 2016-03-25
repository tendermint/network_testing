package main

import (
	"bytes"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"sync"
	"time"
)

var contractAddrHex = flag.String("contract", "4D5F1BB2AED47C6C0F7E1155EE0B91AC34A7BA12", "address of contract")
var chainID = flag.String("chainID", "eris-chain", "chain id")
var nAccounts = flag.Int("n", 8, "number of accounts")

func main() {
	args := os.Args[1:]
	if len(args) < 3 {
		fmt.Println("transact.go expects at least two arguments (mach prefix, nvals, ntxs)")
		os.Exit(1)
	}

	machPrefix, nValsS, nTxsS := args[0], args[1], args[2]
	nTxs, err := strconv.Atoi(nTxsS)
	if err != nil {
		fmt.Println("ntxs must be an integer:", err)
		os.Exit(1)
	}
	nVals, err := strconv.Atoi(nValsS)
	if err != nil {
		fmt.Println("ntxs must be an integer:", err)
		os.Exit(1)
	}

	hosts := make([]string, nVals)
	for i := 0; i < nVals; i++ {
		hosts[i] = machIP(machPrefix, i+1) + ":46657"
	}

	wg := new(sync.WaitGroup)
	wg.Add(len(hosts))
	start := time.Now()
	fmt.Printf("Copying transactor to each host\n")
	nAccs := (*nAccounts + 1) / len(hosts) // +1 because first account used for deploy
	for thisHostI, thisHost := range hosts {
		hostIndex := thisHostI + 1 // plus one because machine names are 1-based
		go runTransactor(wg, hostIndex, thisHost, nTxs, machPrefix, thisHostI*nAccs+1, nAccs)
	}
	wg.Wait()
	fmt.Println("Done starting transactor on all nodes. Took", time.Since(start))
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

func runTransactor(wg *sync.WaitGroup, valI int, valHost string, nTxs int, machPrefix string, startAcc, nAccs int) {
	// copy to machine
	/*
		cmd := exec.Command("docker-machine", "scp", "eris/transact.go", fmt.Sprintf("%s%d:transact.go", machPrefix, valI))
		runCmd(cmd)

		cmd := exec.Command("docker-machine", "scp", "eris/transact_init.sh", fmt.Sprintf("%s%d:transact_init.sh", machPrefix, valI))
		runCmd(cmd)

		cmd := exec.Command("docker-machine", "scp", "eris/getset.abi", fmt.Sprintf("%s%d:getset.abi", machPrefix, valI))
		runCmd(cmd)

		cmd = exec.Command("docker-machine", "ssh", fmt.Sprintf("%s%d", machPrefix, valI), "docker", "cp", "transact.go", "bench_app_tmcommon:/data/tendermint/transact.go")
		runCmd(cmd)

		cmd = exec.Command("docker-machine", "ssh", fmt.Sprintf("%s%d", machPrefix, valI), "docker", "cp", "transact_init.sh", "bench_app_tmcommon:/data/tendermint/transact_init.sh")
		runCmd(cmd)

		cmd = exec.Command("docker-machine", "ssh", fmt.Sprintf("%s%d", machPrefix, valI), "docker", "cp", "getset.abi", "bench_app_tmcommon:/data/tendermint/getset.abi")
		runCmd(cmd)
	*/

	// this one runs in daemon mode!
	cmd := exec.Command("docker-machine", "ssh", fmt.Sprintf("%s%d", machPrefix, valI), "docker", "run", "-d", "--name", "txer",
		"--link=bench_app_tmcore:tmcore",
		"tendermint/erisdbtxer", "go", "run", "/data/tendermint/transact.go",
		"-contract", *contractAddrHex,
		"-abi-file", "getset.abi",
		"-chainID", *chainID,
		"-start-acc", fmt.Sprintf("%d", startAcc),
		"-n-acc", fmt.Sprintf("%d", nAccs),
		fmt.Sprintf("%d", nTxs), "docker_link",
	)
	runCmd(cmd)

	wg.Done()
}

func runCmd(cmd *exec.Cmd) {
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Run()
}
