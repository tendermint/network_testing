# network testing

Some utilities for putting up tendermint test nets and benchmarking throughput and latency in normal and adversarial conditions.

The top level directory contains shell scripts for running each type of experiment over a set of relevant parameters.
The types of experiment are 

- normal - raw null transaction throughput
- crashes - crash -1/3 nodes every 3 seconds for 3 seconds
- byzantine - make -1/3 nodes byzantine
- eris - run eris transactions on erisdb-tmsp

# run all the experiments:

To run, for instance, the normal experiments:

`bash benchmark_throughput.sh <machine prefix> <results dir>`

The script will launch all necessary machines using docker-machine and do all necessary setup, 
writing all results into the `<results dir>`.

Each top level benchmark script contains a loop over something like the following:

```
bash experiments/exp_throughput.sh $DATACENTER $valsetsize $blocksize $TX_SIZE $ntxs $MACH_PREFIX $resultsDir > $resultsDir/experiment.log
```

The `$DATACENTER` param can be set to `single` or `multi`. 

By default, scripts use amazonec2, so make sure to set the correct environment variables,
including AWS_SECURITY_GROUP.

See `utils/launch.sh` for the launch script,
which either uses mintnet for single datacenters or the utils/create.go script for mutliple data centers.
You can change `amazonec2` to `digitalocean` in utils/launch.sh

Most of the experiments are in `experiments/` and many utility scripts can be found in `utils/`. 
Eris has its own folder for experiments since it requires some unique scripts (eg. for transactions).

The tendermint docker image can be specified with the TM_IMAGE environment variable. It defaults to `tendermint/tmbase:dev`,
which is currently the `byzantine` branch of tendermint/tendermint.
It uses experiments/init.sh as a baseline, but will overwrite the file to not install tendermint and just run it if no TM_IMAGE is specified (since tendermint/tmbase:dev comes with tendermint installed already for faster startup).

Note this all requires mintnet on the develop branch (mostly for specifying docker images and print configs for the netmon).

The experiments themselves use the latest version of netmon to track block latency.

A transaction player image is started on every machine to send txs to each validator (see utils/transact_concurrent.go and utils/transact.go)

See the various flags in the scripts for additional control, for using profilers, and for setting other params.

The config file used by the tendermint nodes can be found inline in experiments/start.sh

