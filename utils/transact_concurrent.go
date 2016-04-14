package main

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"sync"
	"time"
)

func main() {
	args := os.Args[1:]
	if len(args) < 3 {
		fmt.Println("transact.go expects three arguments (mach prefix, nvals, ntxs)")
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
	for thisHostI, thisHost := range hosts {
		hostIndex := thisHostI + 1 // plus one because machine names are 1-based
		go runTransactor(wg, hostIndex, thisHost, nTxs, machPrefix)
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

func runTransactor(wg *sync.WaitGroup, valI int, valHost string, nTxs int, machPrefix string) {
	// this one runs in daemon mode!
	cmd := exec.Command("docker-machine", "ssh", fmt.Sprintf("%s%d", machPrefix, valI), "docker", "run", "-d", "--link=bench_app_tmcore:tmcore", "tendermint/transacter", "transacter", fmt.Sprintf("%d", nTxs), "docker_link")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Run()

	wg.Done()
}
