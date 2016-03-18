#! /bin/bash

TMREPO="github.com/tendermint/tendermint"
BRANCH="develop"

go get -d $TMREPO/cmd/tendermint
cd $GOPATH/src/$TMREPO
git fetch origin $BRANCH
git checkout $BRANCH
glide install
go install ./cmd/tendermint
