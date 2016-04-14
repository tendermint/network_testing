package main

import (
	"fmt"
	"math/rand"
	"os"
	"os/exec"
	"strconv"
	"sync"
)

func randInt(n int) int {
	return int(rand.Int31()) % n
}

var DO_REGIONS = []string{"tor1", "ams2", "sgp1", "lon1", "nyc3", "fra1"}
var EC2_REGIONS = []string{"us-east-1", "eu-central-1", "ap-northeast-1", "ap-southeast-2", "sa-east-1", "us-west-2", "eu-west-1"}

func main() {
	args := os.Args[1:]
	if len(args) < 4 {
		fmt.Println("Expected args <driver> <prefix> <startN> <endN>")
		os.Exit(1)
	}
	driver, prefix, startNstring, endNstring := args[0], args[1], args[2], args[3]

	startN, err := strconv.Atoi(startNstring)
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
	endN, err := strconv.Atoi(endNstring)
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}

	switch driver {
	case "digitalocean":
		createDigitalOceanMachines(prefix, startN, endN)
	case "amazonec2":
		createAmazonEC2Machines(prefix, startN, endN)
	default:
		fmt.Println("Not implemented yet")
		os.Exit(1)
	}
}

func createDigitalOceanMachines(prefix string, startN, endN int) {
	n := endN - startN + 1
	wg := new(sync.WaitGroup)
	wg.Add(n)
	for i := startN - 1; i < endN; i++ {
		var region string
		if i < len(DO_REGIONS) {
			region = DO_REGIONS[i]
		} else {
			region = DO_REGIONS[randInt(len(DO_REGIONS))]
		}
		fmt.Printf("###### LAUNCHING MACHINE %d in region %s\n", i+1, region)
		go createDigitalOceanMachine(wg, prefix, region, i+1)
	}
	wg.Wait()
}

func createDigitalOceanMachine(wg *sync.WaitGroup, prefix, region string, i int) {
	cmd := exec.Command("docker-machine", "create", fmt.Sprintf("%s%d", prefix, i),
		"--driver=digitalocean",
		"--digitalocean-access-token="+os.Getenv("DIGITALOCEAN_ACCESS_TOKEN"),
		"--digitalocean-size=1gb",
		"--digitalocean-region="+region)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Run()
	wg.Done()
}

func createAmazonEC2Machines(prefix string, startN, endN int) {
	n := endN - startN + 1
	wg := new(sync.WaitGroup)
	wg.Add(n)
	for i := startN - 1; i < endN; i++ {
		var region string
		if i < len(EC2_REGIONS) {
			region = EC2_REGIONS[i]
		} else {
			region = EC2_REGIONS[randInt(len(EC2_REGIONS))]
		}
		fmt.Printf("###### LAUNCHING MACHINE %d in region %s\n", i+1, region)
		go createAmazonEC2Machine(wg, prefix, region, i+1)
	}
	wg.Wait()
}

func createAmazonEC2Machine(wg *sync.WaitGroup, prefix, region string, i int) {
	instanceType := os.Getenv("AWS_INSTANCE_TYPE")
	if instanceType == "" {
		instanceType = "t2.medium"
	}
	cmd := exec.Command("docker-machine", "create", fmt.Sprintf("%s%d", prefix, i),
		"--driver=amazonec2",
		"--amazonec2-access-key="+os.Getenv("AWS_ACCESS_KEY"),
		"--amazonec2-secret-key="+os.Getenv("AWS_SECRET_KEY"),
		//"--amazonec2-vpc-id="+os.Getenv("AWS_VPC_ID"),
		"--amazonec2-security-group="+os.Getenv("AWS_SECURITY_GROUP"),
		"--amazonec2-instance-type="+instanceType,
		"--amazonec2-region="+region)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Run()

	// need to add base user to docker group
	cmd = exec.Command("docker-machine", "ssh", fmt.Sprintf("%s%d", prefix, i),
		"sudo", "usermod", "-aG", "docker", "ubuntu")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Run()
	wg.Done()
}
