#!/bin/bash

set -eu 
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source ${SCRIPT_DIR}/config.sh

# cleanup any stale state
rm -rf $STATE $LOGS 
mkdir -p $STATE
mkdir -p $LOGS

# Initialize the state for each chain
bash $SRC/init_chain.sh SIMD


# Start each chain, create the transfer channels and start the relayers
bash $SRC/start_chain.sh 

