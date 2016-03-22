#! /bin/bash

REPO="github.com/eris-ltd/eris-db"
BRANCH="tmsp"

go get -d $REPO/cmd/erisdb
cd $GOPATH/src/$REPO
git fetch origin $BRANCH
git checkout $BRANCH
go install ./cmd/erisdb
