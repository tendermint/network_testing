#! /bin/bash

TMREPO="github.com/tendermint/tendermint"
BRANCH="develop"

go get -d \$TMREPO/cmd/tendermint
cd \$GOPATH/src/\$TMREPO
git fetch origin \$BRANCH
git checkout \$BRANCH
glide install

# fetch this repo for the altered main.go file (preloads txs)
git clone https://github.com/tendermint/network_testing ./network_testing
cp -r ./cmd/tendermint ./cmd/mintbench
cp ./network_testing/tendermint/main.go ./cmd/mintbench/main.go

go install ./cmd/mintbench
go install ./cmd/tendermint
