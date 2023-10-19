#!/bin/bash

set -eu 
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

source $SCRIPT_DIR/../config.sh

CHAIN="$1"
KEYS_LOGS=$DOCKERNET_HOME/logs/keys.log

CHAIN_ID=$(GET_VAR_VALUE    ${CHAIN}_CHAIN_ID)
BINARY=$(GET_VAR_VALUE      ${CHAIN}_BINARY)
MAIN_CMD=$(GET_VAR_VALUE    ${CHAIN}_MAIN_CMD)
DENOM=$(GET_VAR_VALUE       ${CHAIN}_DENOM)
RPC_PORT=$(GET_VAR_VALUE    ${CHAIN}_RPC_PORT)
NUM_NODES=$(GET_VAR_VALUE   ${CHAIN}_NUM_NODES)
NODE_PREFIX=$(GET_VAR_VALUE ${CHAIN}_NODE_PREFIX)
VAL_PREFIX=$(GET_VAR_VALUE  ${CHAIN}_VAL_PREFIX)
# THe host zone can optionally specify additional the micro-denom granularity
# If they don't specify the ${CHAIN}_MICRO_DENOM_UNITS variable,
# EXTRA_MICRO_DENOM_UNITS will include 6 0's
MICRO_DENOM_UNITS_VAR_NAME=${CHAIN}_MICRO_DENOM_UNITS
MICRO_DENOM_UNITS="${!MICRO_DENOM_UNITS_VAR_NAME:-000000}"

VAL_TOKENS=${VAL_TOKENS}${MICRO_DENOM_UNITS}
STAKE_TOKENS=${STAKE_TOKENS}${MICRO_DENOM_UNITS}
ADMIN_TOKENS=${ADMIN_TOKENS}${MICRO_DENOM_UNITS}
USER_TOKENS=${USER_TOKENS}${MICRO_DENOM_UNITS}

set_simd_genesis() {
    genesis_config=$1

    # set params
    jq '.app_state.staking.params.unbonding_time = $newVal' --arg newVal "$UNBONDING_TIME" $genesis_config > json.tmp && mv json.tmp $genesis_config
    jq '.app_state.gov.deposit_params.max_deposit_period = $newVal' --arg newVal "$MAX_DEPOSIT_PERIOD" $genesis_config > json.tmp && mv json.tmp $genesis_config
    jq '.app_state.gov.voting_params.voting_period = $newVal' --arg newVal "$VOTING_PERIOD" $genesis_config > json.tmp && mv json.tmp $genesis_config
    jq '.app_state["tokenfactory"]["params"]["denom_creation_fee"][0]["denom"]="stake"' $genesis_config > json.tmp && mv json.tmp $genesis_config
    jq '.app_state["tokenfactory"]["params"]["denom_creation_fee"][0]["amount"]="1000000"' $genesis_config > json.tmp && mv json.tmp $genesis_config
}

MAIN_ID=1 # Node responsible for genesis and persistent_peers
MAIN_NODE_NAME=""
MAIN_NODE_ID=""
MAIN_CONFIG=""
MAIN_GENESIS=""
echo "Initializing $CHAIN chain..."
echo "$CHAIN_ID"
echo "$NUM_NODES"
for (( i=1; i <= $NUM_NODES; i++ )); do
    # Node names will be of the form: "simd1"
    node_name="${NODE_PREFIX}${i}"
    # Moniker is of the form: SIMD_1
    moniker=$(printf "${NODE_PREFIX}_${i}" | awk '{ print toupper($0) }')

    # Create a state directory for the current node and initialize the chain
    mkdir -p $STATE/$node_name
    
    # If the chains commands are run only from docker, grab the command from the config
    # Otherwise, if they're run locally, append the home directory
    cmd="$BINARY --home ${STATE}/$node_name"
    # Initialize the chain
    $cmd init $moniker --chain-id $CHAIN_ID --overwrite &> /dev/null
    chmod -R 777 $STATE/$node_name

    # Update node networking configuration 
    config_toml="${STATE}/${node_name}/config/config.toml"
    client_toml="${STATE}/${node_name}/config/client.toml"
    app_toml="${STATE}/${node_name}/config/app.toml"
    genesis_json="${STATE}/${node_name}/config/genesis.json"

    sed -i -E "s|cors_allowed_origins = \[\]|cors_allowed_origins = [\"\*\"]|g" $config_toml
    sed -i -E "s|127.0.0.1|0.0.0.0|g" $config_toml
    sed -i -E "s|timeout_commit = \"5s\"|timeout_commit = \"${BLOCK_TIME}\"|g" $config_toml
    sed -i -E "s|prometheus = false|prometheus = true|g" $config_toml

    sed -i -E "s|minimum-gas-prices = \".*\"|minimum-gas-prices = \"0${DENOM}\"|g" $app_toml
    sed -i -E '/\[api\]/,/^enable = .*$/ s/^enable = .*$/enable = true/' $app_toml
    sed -i -E 's|unsafe-cors = .*|unsafe-cors = true|g' $app_toml
    sed -i -E "s|snapshot-interval = 0|snapshot-interval = 300|g" $app_toml
    sed -i -E 's|localhost|0.0.0.0|g' $app_toml

    sed -i -E "s|chain-id = \"\"|chain-id = \"${CHAIN_ID}\"|g" $client_toml
    sed -i -E "s|keyring-backend = \"os\"|keyring-backend = \"test\"|g" $client_toml
    sed -i -E "s|node = \".*\"|node = \"tcp://localhost:$RPC_PORT\"|g" $client_toml

    sed -i -E "s|\"stake\"|\"${DENOM}\"|g" $genesis_json 
    sed -i -E "s|\"aphoton\"|\"${DENOM}\"|g" $genesis_json # ethermint default

    # add a validator account
    val_acct="${VAL_PREFIX}${i}"
    val_mnemonic="${VAL_MNEMONICS[((i-1))]}"
    echo "$val_mnemonic" | $cmd keys add $val_acct --recover --keyring-backend=test >> $KEYS_LOGS 2>&1
    val_addr=$($cmd keys show $val_acct --keyring-backend test -a | tr -cd '[:alnum:]._-')
    # Add this account to the current node
    $cmd add-genesis-account ${val_addr} ${VAL_TOKENS}${DENOM}

    # Copy over the provider simd validator keys to the provider (in the event
    # that we are testing ICS)
    if [[ $CHAIN == "GAIA" && -d $DOCKERNET_HOME/state/${SIMD_NODE_PREFIX}${i} ]]; then
        simd_config=$DOCKERNET_HOME/state/${SIMD_NODE_PREFIX}${i}/config
        host_config=$DOCKERNET_HOME/state/${NODE_PREFIX}${i}/config
        cp ${simd_config}/priv_validator_key.json ${host_config}/priv_validator_key.json
        cp ${simd_config}/node_key.json ${host_config}/node_key.json
    fi

    # Only generate the validator txs for host chains
    $cmd gentx $val_acct ${STAKE_TOKENS}${DENOM} --chain-id $CHAIN_ID --keyring-backend test &> /dev/null
    
    
    # Get the endpoint and node ID
    node_id=$($cmd tendermint show-node-id)@$node_name:$PEER_PORT
    echo "Node #$i ID: $node_id"

    # Cleanup from seds
    rm -rf ${client_toml}-E
    rm -rf ${genesis_json}-E
    rm -rf ${app_toml}-E

    if [ $i -eq $MAIN_ID ]; then
        MAIN_NODE_NAME=$node_name
        MAIN_NODE_ID=$node_id
        MAIN_CONFIG=$config_toml
        MAIN_GENESIS=$genesis_json
    else
        # also add this account and it's genesis tx to the main node
        $MAIN_CMD add-genesis-account ${val_addr} ${VAL_TOKENS}${DENOM}
        if [ -d "${STATE}/${node_name}/config/gentx" ]; then
            cp ${STATE}/${node_name}/config/gentx/*.json ${STATE}/${MAIN_NODE_NAME}/config/gentx/
        fi

        # and add each validator's keys to the first state directory
        echo "$val_mnemonic" | $MAIN_CMD keys add $val_acct --recover --keyring-backend=test &> /dev/null
    fi
done

# add a staker account for integration tests
# the account should live on both stride and the host chain
echo "$USER_MNEMONIC" | $MAIN_CMD keys add $USER_ACCT --recover --keyring-backend=test >> $KEYS_LOGS 2>&1
USER_ADDRESS=$($MAIN_CMD keys show $USER_ACCT --keyring-backend test -a)
$MAIN_CMD add-genesis-account ${USER_ADDRESS} ${USER_TOKENS}${DENOM}

# add alice with 100stake
$MAIN_CMD keys add alice --keyring-backend=test >> $KEYS_LOGS 2>&1
ALICE_ADDRESS=$($MAIN_CMD keys show alice --keyring-backend test -a)
$MAIN_CMD add-genesis-account ${ALICE_ADDRESS} ${USER_TOKENS}${DENOM}

# add bob with 2000000stake
$MAIN_CMD keys add bob --keyring-backend=test >> $KEYS_LOGS 2>&1
BOB_ADDRESS=$($MAIN_CMD keys show bob --keyring-backend test -a)
$MAIN_CMD add-genesis-account ${BOB_ADDRESS} 2000000stake

# Only collect the validator genesis txs for host chains
$MAIN_CMD collect-gentxs &> /dev/null


# wipe out the persistent peers for the main node (these are incorrectly autogenerated for each validator during collect-gentxs)
sed -i -E "s|persistent_peers = .*|persistent_peers = \"\"|g" $MAIN_CONFIG

set_simd_genesis $MAIN_GENESIS

echo $MAIN_NODE_ID
# for all peer nodes....
for (( i=2; i <= $NUM_NODES; i++ )); do
    node_name="${NODE_PREFIX}${i}"
    config_toml="${STATE}/${node_name}/config/config.toml"
    genesis_json="${STATE}/${node_name}/config/genesis.json"
    echo $MAIN_NODE_ID
    # add the main node as a persistent peer
    sed -i -E "s|persistent_peers = .*|persistent_peers = \"${MAIN_NODE_ID}\"|g" $config_toml
    # copy the main node's genesis to the peer nodes to ensure they all have the same genesis
    cp $MAIN_GENESIS $genesis_json

    rm -rf ${config_toml}-E
done

# Cleanup from seds
rm -rf ${MAIN_CONFIG}-E
rm -rf ${MAIN_GENESIS}-E