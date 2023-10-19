#!/bin/bash

set -eu
DOCKERNET_HOME=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

STATE=$DOCKERNET_HOME/state
LOGS=$DOCKERNET_HOME/logs
SRC=$DOCKERNET_HOME/src
PEER_PORT=26656
DOCKER_COMPOSE="docker-compose -f $DOCKERNET_HOME/docker-compose.yml"

# Logs
SIMD_LOGS=$LOGS/simd.log
TX_LOGS=$DOCKERNET_HOME/logs/tx.log
KEYS_LOGS=$DOCKERNET_HOME/logs/keys.log

# COIN TYPES
# Coin types can be found at https://github.com/satoshilabs/slips/blob/master/slip-0044.md
COSMOS_COIN_TYPE=118
ETH_COIN_TYPE=60
TERRA_COIN_TYPE=330

# CHAIN PARAMS
BLOCK_TIME='1s'
SIMD_HOUR_EPOCH_DURATION="90s"
SIMD_DAY_EPOCH_DURATION="140s"
SIMD_EPOCH_EPOCH_DURATION="35s"
SIMD_MINT_EPOCH_DURATION="20s"
UNBONDING_TIME="240s"
MAX_DEPOSIT_PERIOD="30s"
VOTING_PERIOD="30s"
INITIAL_ANNUAL_PROVISIONS="10000000000000.000000000000000000"

# LSM Params
LSM_VALIDATOR_BOND_FACTOR="250"
LSM_GLOBAL_LIQUID_STAKING_CAP="0.25"
LSM_VALIDATOR_LIQUID_STAKING_CAP="0.50"

# Tokens are denominated in the macro-unit 
# (e.g. 5000000STRD implies 5000000000000ustrd)
VAL_TOKENS=5000000
STAKE_TOKENS=5000
ADMIN_TOKENS=1000
USER_TOKENS=100

# CHAIN MNEMONICS
VAL_MNEMONIC_1="close soup mirror crew erode defy knock trigger gather eyebrow tent farm gym gloom base lemon sleep weekend rich forget diagram hurt prize fly"
VAL_MNEMONIC_2="turkey miss hurry unable embark hospital kangaroo nuclear outside term toy fall buffalo book opinion such moral meadow wing olive camp sad metal banner"
VAL_MNEMONIC_3="tenant neck ask season exist hill churn rice convince shock modify evidence armor track army street stay light program harvest now settle feed wheat"
VAL_MNEMONIC_4="tail forward era width glory magnet knock shiver cup broken turkey upgrade cigar story agent lake transfer misery sustain fragile parrot also air document"
VAL_MNEMONIC_5="crime lumber parrot enforce chimney turtle wing iron scissors jealous indicate peace empty game host protect juice submit motor cause second picture nuclear area"
VAL_MNEMONICS=(
    "$VAL_MNEMONIC_1"
    "$VAL_MNEMONIC_2"
    "$VAL_MNEMONIC_3"
    "$VAL_MNEMONIC_4"
    "$VAL_MNEMONIC_5"
)
REV_MNEMONIC="tonight bonus finish chaos orchard plastic view nurse salad regret pause awake link bacon process core talent whale million hope luggage sauce card weasel"
USER_MNEMONIC="brief play describe burden half aim soccer carbon hope wait output play vacuum joke energy crucial output mimic cruise brother document rail anger leaf"
USER_ACCT=user

# SIMD 
SIMD_CHAIN_ID=SIMD
SIMD_NODE_PREFIX=simd
SIMD_NUM_NODES=4
SIMD_VAL_PREFIX=val
SIMD_ADDRESS_PREFIX=cosmos
SIMD_DENOM="stake"
SIMD_RPC_PORT=26657
SIMD_BINARY="$DOCKERNET_HOME/../build/simd"
SIMD_MAIN_CMD="$SIMD_BINARY --home $DOCKERNET_HOME/state/${SIMD_NODE_PREFIX}1"
CREATION_FEE_DENOM="stake"
CREATION_FEE_AMOUNT="1000000"

CSLEEP() {
  for i in $(seq $1); do
    sleep 1
    printf "\r\t$(($1 - $i))s left..."
  done
}

GET_VAR_VALUE() {
  var_name="$1"
  echo "${!var_name}"
}

WAIT_FOR_BLOCK() {
  num_blocks="${2:-1}"
  for i in $(seq $num_blocks); do
    ( tail -f -n0 $1 & ) | grep -q "executed block.*height="
  done
}

WAIT_FOR_STRING() {
  ( tail -f -n0 $1 & ) | grep -q "$2"
}

GET_VAL_ADDR() {
  chain=$1
  val_index=$2

  MAIN_CMD=$(GET_VAR_VALUE ${chain}_MAIN_CMD)
  $MAIN_CMD q staking validators | grep ${chain}_${val_index} -A 6 | grep operator | awk '{print $2}'
}


TRIM_TX() {
  grep -E "code:|txhash:" | sed 's/^/  /'
}

NUMBERS_ONLY() {
  tr -cd '[:digit:]'
}

GETBAL() {
  head -n 1 | grep -o -E '[0-9]+' || "0"
}

GETSTAKE() {
  tail -n 2 | head -n 1 | grep -o -E '[0-9]+' | head -n 1
}
