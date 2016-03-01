#! /bin/bash

MACH_PREFIX=$1
GLOBAL=$2
START_N=$3
END_N=$4
REGION=$5

if [[ "$GLOBAL" == "single" ]]; then
	mintnet create --machine "${MACH_PREFIX}[${START_N}-${END_N}]" -- --driver=digitalocean --digitalocean-access-token $DO_TOKEN  --digitalocean-region "$REGION"
elif [[ "$GLOBAL" == "multi" ]]; then
	go run create.go digitalocean $MACH_PREFIX $START_N $END_N
fi
