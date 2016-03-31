#! /bin/bash

mach=$1
profDir=$2

docker-machine ssh $mach docker cp bench_app_tmcore:/go/bin/tendermint tendermint.bin
docker-machine ssh $mach docker cp bench_app_tmcore:/data/tendermint/core/cpu.prof cpu.prof

mkdir -p $profDir

docker-machine scp $mach:tendermint.bin  $profDir/tendermint.bin
docker-machine scp $mach:cpu.prof $profDir/cpu.prof
