#!/bin/bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# run test files
BATS=${SCRIPT_DIR}/bats/bats-core/bin/bats
INTEGRATION_TEST_FILE=${SCRIPT_DIR}/integration_tests.bats 

$BATS $INTEGRATION_TEST_FILE
