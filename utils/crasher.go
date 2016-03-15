package main

import (
	"fmt"
	"math/rand"
	"os"
	"os/exec"
	"strconv"
	"time"
)

func main() {
	args := os.Args[1:]
	if len(args) < 3 {
		fmt.Println("Expected args <mach_prefix> <N> <containerName>")
		os.Exit(1)
	}
	prefix, nString, containerName := args[0], args[1], args[2]

	n, err := strconv.Atoi(nString)
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}

	i := rand.Int31n(int32(n))
	stopAndStart(prefix, i, containerName)
}

func stopAndStart(prefix string, i int32, containerName string) {
	fmt.Printf("Stopping node %s%d ... ", prefix, i)
	mach := fmt.Sprintf("%s%d", prefix, i)
	cmd := exec.Command("docker-machine", "ssh", mach, "docker", "stop", containerName)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Run()
	fmt.Println("done")

	time.Sleep(time.Second)

	fmt.Println("Starting node", prefix, i)
	cmd = exec.Command("docker-machine", "ssh", mach, "docker", "start", containerName)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Run()
}
