#!/bin/bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# run test files
INTEGRATION_TEST_FILE=${SCRIPT_DIR}/integration_tests.sh

bash $INTEGRATION_TEST_FILE
