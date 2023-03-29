#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Load environment variables
source $SCRIPT_DIR/loadEnv.sh

forge snapshot --match-path "test/moonbase/*" --no-match-path "test/sudoswap/*" --fork-url $LOCAL_PROVIDER "$@"
