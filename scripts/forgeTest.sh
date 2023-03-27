#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Load environment variables
source $SCRIPT_DIR/loadEnv.sh

forge test --match-path "test/moonbase/*" --no-match-path "test/sudoswap/*" --fork-url $LOCAL_PROVIDER --fork-block-number $FORK_BLOCK_NUMBER "$@"
