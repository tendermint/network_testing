#! /bin/bash

MACH_PREFIX=$1
N=$2

mintnet docker --machines "${MACH_PREFIX}[1-${N}]" -- rm -vf \$\(docker ps -aq\)
