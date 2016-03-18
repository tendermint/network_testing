#! /bin/bash

profDir=$1

mach=benchahoy1
docker-machine ssh $mach docker cp bench_app_tmnode:/go/bin/tendermint tendermint.bin
docker-machine ssh $mach docker cp bench_app_tmnode:/data/tendermint/core/cpu.prof cpu.prof

mkdir -p $profDir

docker-machine scp $mach:tendermint.bin  $profDir/tendermint.bin
docker-machine scp $mach:cpu.prof $profDir/cpu.prof
