package main

import (
	"fmt"
	"os"
	"os/exec"
	"path"
	"strconv"
	"sync"
)

func main() {
	args := os.Args[1:]
	if len(args) < 3 {
		fmt.Println("Expected args <mach_prefix> <results dir> <N>")
		os.Exit(1)
	}
	prefix, resultsDir, nString := args[0], args[1], args[2]

	n, err := strconv.Atoi(nString)
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}

	wg := new(sync.WaitGroup)
	wg.Add(n)
	for i := 1; i <= n; i++ {
		go collectLogs(wg, prefix, i, resultsDir)
	}
	wg.Wait()
}

func collectLogs(wg *sync.WaitGroup, prefix string, i int, resultsDir string) {
	mach := fmt.Sprintf("%s%d", prefix, i)
	dir := fmt.Sprintf("%s/%d", resultsDir, i)
	if err := os.MkdirAll(dir, 0700); err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
	cmd := exec.Command("docker-machine", "scp", mach+":cswal", path.Join(dir, "cswal"))
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Run()

	runCommandToFile("docker-machine", []string{"inspect", mach}, path.Join(dir, "inspect"))
	runCommandToFile("docker-machine", []string{"ssh", mach, "docker", "logs", "bench_app_tmnode"}, path.Join(dir, "tendermint.log"))

	wg.Done()
}

func runCommandToFile(command string, args []string, filename string) {
	f, err := os.Create(filename)
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
	cmd := exec.Command(command, args...)
	cmd.Stdout = f
	cmd.Stderr = f
	cmd.Run()
	f.Close()
}
