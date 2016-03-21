package main

import (
	"flag"
	"fmt"
	"math/rand"
	"os"
	"os/exec"
	"strconv"
	"sync"
	"time"
)

var sleepSeconds = flag.Int("sleep", 3, "Time to sleep between stop/start for a batch, and between batches")

func main() {
	args := os.Args[1:]
	if len(args) < 3 {
		fmt.Println("Expected args <mach_prefix> <N> <containerName>")
		os.Exit(1)
	}
	prefix, nString, containerName := args[0], args[1], args[2]

	nvals, err := strconv.Atoi(nString)
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}

	ncrash := (nvals - 1) / 3
	for {
		perm := rand.Perm(nvals)
		perm = perm[:ncrash]

		wg := new(sync.WaitGroup)
		wg.Add(ncrash)
		for _, machIndex := range perm {
			machIndex += 1 //  machines are 1-based
			go stopAndStart(wg, prefix, machIndex, containerName)
		}
		wg.Wait()
		time.Sleep(time.Second * time.Duration(*sleepSeconds))
	}
}

func stopAndStart(wg *sync.WaitGroup, prefix string, i int, containerName string) {
	fmt.Printf("Stopping node %s%d ... ", prefix, i)
	mach := fmt.Sprintf("%s%d", prefix, i)
	cmd := exec.Command("docker-machine", "ssh", mach, "docker", "stop", containerName)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Run()

	time.Sleep(time.Second * time.Duration(*sleepSeconds))

	fmt.Println("Starting node", prefix, i)
	cmd = exec.Command("docker-machine", "ssh", mach, "docker", "start", containerName)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Run()

	wg.Done()
}
