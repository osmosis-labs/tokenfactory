#!/bin/bash

KEY="test"
CHAINID="simapp-testnet-1"
KEYRING="test"
MONIKER="localtestnet"
KEYALGO="secp256k1"
LOGLEVEL="info"

echo >&1 "installing simapp"
rm -rf $HOME/.simapp*
make install

simd config keyring-backend $KEYRING
simd config chain-id $CHAINID
simd keys add $KEY --keyring-backend $KEYRING --algo $KEYALGO

# init chain
simd init $MONIKER --chain-id $CHAINID

# Change parameter token denominations to stake
cat $HOME/.simapp/config/genesis.json | jq '.app_state["tokenfactory"]["params"]["denom_creation_fee"]["denom"]="stake"' > $HOME/.simapp/config/tmp_genesis.json && mv $HOME/.simapp/config/tmp_genesis.json $HOME/.simapp/config/genesis.json
cat $HOME/.simapp/config/genesis.json | jq '.app_state["tokenfactory"]["params"]["denom_creation_fee"]["amount"]="10"' > $HOME/.simapp/config/tmp_genesis.json && mv $HOME/.simapp/config/tmp_genesis.json $HOME/.simapp/config/genesis.json

# Set gas limit in genesis
# cat $HOME/.simapp/config/genesis.json | jq '.consensus_params["block"]["max_gas"]="10000000"' > $HOME/.simapp/config/tmp_genesis.json && mv $HOME/.simapp/config/tmp_genesis.json $HOME/.simapp/config/genesis.json

# Allocate genesis accounts (cosmos formatted addresses)
simd add-genesis-account $KEY 1000000000000stake --keyring-backend $KEYRING

# Sign genesis transaction
simd gentx $KEY 1000000stake --keyring-backend $KEYRING --chain-id $CHAINID

# Collect genesis tx
simd collect-gentxs

# Run this to ensure everything worked and that the genesis file is setup correctly
simd validate-genesis

# Start the node (remove the --pruning=nothing flag if historical queries are not needed)
simd start --pruning=nothing --log_level $LOGLEVEL --minimum-gas-prices=0.0001stake
