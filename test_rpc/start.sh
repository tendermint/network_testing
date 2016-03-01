#! /bin/bash

MACH_PREFIX=$1
N=$2
NODE_DIRS=$3

# initialize directories
mintnet init --machines "${MACH_PREFIX}[1-${N}]" chain --app-hash nil $NODE_DIRS

# start the nodes
mintnet start --machines "$MACH_PREFIX[1-${N}]" --no-tmsp bench_app $NODE_DIRS
