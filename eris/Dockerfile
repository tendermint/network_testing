# Pull base image.
FROM golang:1.5

# for transactor

ENV USER tmuser
ENV DATA_ROOT /data/tendermint

# Set user right away for determinism
RUN groupadd -r $USER \
  && useradd -r -s /bin/false -g $USER $USER

# Create home directory for USER
# Needed for nodejs/nom
RUN mkdir -p /home/$USER \
  && chown -R $USER:$USER /home/$USER

# Create directory for persistence and give our user ownership
RUN mkdir -p $DATA_ROOT \
  && chown -R $USER:$USER $DATA_ROOT

# Set the env variables to non-interactive
ENV DEBIAN_FRONTEND noninteractive
ENV DEBIAN_PRIORITY critical
ENV DEBCONF_NOWARNINGS yes
ENV TERM linux
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

# Grab deps (git)
RUN apt-get update && \
  apt-get install -y --no-install-recommends \
    git && \
  rm -rf /var/lib/apt/lists/*

# set go vendoring
ENV GO15VENDOREXPERIMENT 1

# install glide for golang pkg dev
ENV REPO $GOPATH/src/github.com/Masterminds/glide
RUN mkdir -p $REPO
RUN git clone https://github.com/Masterminds/glide $REPO
RUN cd $REPO && make build && cp glide /usr/local/bin/

# install erisdb tmsp
ENV REPO "github.com/eris-ltd/eris-db"
ENV BRANCH "tmsp"

RUN mkdir -p $GOPATH/src/$REPO
RUN git clone https://$REPO $GOPATH/src/$REPO
WORKDIR $GOPATH/src/$REPO
RUN git fetch origin $BRANCH && git checkout $BRANCH 
RUN go get ./account
RUN go get ./txs

RUN go get github.com/eris-ltd/eris-abi/...
RUN go get github.com/tendermint/go-rpc/...
RUN go get github.com/tendermint/go-merkle/...

# Persist data, set user
WORKDIR $DATA_ROOT
VOLUME $DATA_ROOT

# copy in some data
COPY transact.go /data/tendermint/transact.go
COPY getset.abi /data/tendermint/getset.abi

USER $USER
ENV TMROOT $DATA_ROOT

EXPOSE 46656
EXPOSE 46657

RUN go build /data/tendermint/transact.go

# overwrite
CMD ["go", "run", "/data/tendermint/transact.go"]
