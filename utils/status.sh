#! /bin/bash

MACH_PREFIX=$1
N=$2

for i in `seq 1 $N`; do
	curl -s --max-time 1 $(docker-machine ip ${MACH_PREFIX}$i):46657/status | jq . | grep moniker
done
