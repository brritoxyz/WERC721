#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Load environment variables
source $SCRIPT_DIR/loadEnv.sh

forge test --fork-url $LOCAL_PROVIDER --fork-block-number $FORK_BLOCK_NUMBER "$@"
