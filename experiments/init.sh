#! /bin/bash
set -eu

TMREPO="github.com/tendermint/tendermint"
TMHEAD="byzantine"

go get -d $TMREPO/cmd/tendermint
cd $GOPATH/src/$TMREPO
git fetch origin $TMHEAD
git checkout $TMHEAD
glide install
go install ./cmd/tendermint
