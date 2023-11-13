#!/bin/bash

set -eu 
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
echo $SCRIPT_DIR
echo $BASH_SOURCE
source ${SCRIPT_DIR}/config.sh

# cleanup any stale state
rm -rf $STATE $LOGS 
mkdir -p $STATE
mkdir -p $LOGS

# Initialize the state for each chain
bash $SCRIPT_DIR/init_chain.sh SIMD


# Start each chain, create the transfer channels and start the relayers
bash $SCRIPT_DIR/start_chain.sh 

