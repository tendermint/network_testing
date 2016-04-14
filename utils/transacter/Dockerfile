# Pull base image.
FROM tendermint/tmbase:dev

USER root

ENV REPO $GOPATH/src/github.com/tendermint/transacter
RUN mkdir $REPO
COPY transact.go $REPO
WORKDIR $REPO
RUN go get .
RUN go install

USER tmuser
