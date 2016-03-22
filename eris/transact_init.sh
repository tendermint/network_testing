#! /bin/bash

go get github.com/eris-ltd/eris-db
cd $GOPATH/src/github.com/eris-ltd/eris-db
git checkout tmsp
rm -rf vendor
go get -u ./...

cd /data/tendermint
go run transact.go -chainID $CHAINID -abi-file getset.abi -start-acc $START_ACC -n-acc $N_ACCS --contract $CONTRACT_ADDR


