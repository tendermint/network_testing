package main

import (
	"flag"
	"fmt"

	// uses eris-db:tmsp with no vendor dir
	acm "github.com/eris-ltd/eris-db/account"
	gentypes "github.com/eris-ltd/eris-db/state/types"
	"github.com/tendermint/go-crypto"
	"github.com/tendermint/go-wire"
)

// Create a genesis.json with a deterministic set of accounts
// (and a random validator cuz we ignore it)

var nAccounts = flag.Int("n", 1000, "number of accounts")
var chainID = flag.String("chainID", "eris-chain", "chain ID")

func main() {
	flag.Parse()

	nAccs := *nAccounts + 1 // first account used for deploying
	accounts := make([]gentypes.GenesisAccount, nAccs)
	for i := 0; i < nAccs; i++ {
		secret := fmt.Sprintf("%d", i)
		privAcc := acm.GenPrivAccountFromSecret(secret)
		accounts[i] = gentypes.GenesisAccount{
			Address: privAcc.Address,
			Amount:  1000000,
			Name:    secret,
		}
	}

	val := acm.GenPrivAccount()
	validators := []gentypes.GenesisValidator{
		gentypes.GenesisValidator{
			PubKey: val.PubKey.(crypto.PubKeyEd25519),
			Amount: 100,
			Name:   "val",
			UnbondTo: []gentypes.BasicAccount{
				{
					Address: val.Address,
				},
			},
		},
	}

	genDoc := gentypes.GenesisDoc{
		ChainID:    *chainID,
		Accounts:   accounts,
		Validators: validators,
	}
	fmt.Println(string(wire.JSONBytes(genDoc)))
}
