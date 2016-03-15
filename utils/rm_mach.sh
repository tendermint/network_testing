#! /bin/bash

MACH_PREFIX=$1
N=$2

for i in `seq 1 $N`; do 
	docker-machine rm -f ${MACH_PREFIX}$i
done
