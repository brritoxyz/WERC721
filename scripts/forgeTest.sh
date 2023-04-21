#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Load environment variables
source $SCRIPT_DIR/loadEnv.sh

forge snapshot --fork-url $LOCAL_PROVIDER --fork-block-number $FORK_BLOCK_NUMBER --gas-report --etherscan-api-key $ETHERSCAN_API_KEY "$@"
