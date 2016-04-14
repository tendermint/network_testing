#! /bin/bash

REPO="github.com/eris-ltd/eris-db"
BRANCH="tmsp_dev"

mkdir -p $GOPATH/src/github.com/eris-ltd
git clone https://$REPO $GOPATH/src/$REPO
cd $GOPATH/src/$REPO
git checkout $BRANCH
glide install
go install ./cmd/erisdb

cd /data/tendermint/app
erisdb .
