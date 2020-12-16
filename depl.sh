#!/bin/bash -eEx

DEP_VALUE=5"000000000"
STPARS="\"value\":$DEP_VALUE, \"bounce\":false"

echo "******************** Compiling contract ********************"
solc CondTran.sol

echo "******************** Linking contract   ********************"
tvm_linker compile CondTran.code -o ct.tvc

echo "******************** Generating keys    ********************"
tonos-cli genaddr ct.tvc CondTran.abi.json --genkey ct.keys.json

ADDR=$(tonos-cli genaddr ct.tvc CondTran.abi.json --setkey ct.keys.json | grep 'Raw address' | cut -d' ' -f3)
WAL_ADDR=$(tonos-cli genaddr wallet.tvc Wallet.abi.json --setkey wkeys.json | grep 'Raw address' | cut -d' ' -f3)

echo "******************** Predeploying CT SC ********************"
tonos-cli call "$WAL_ADDR" sendTransaction "{\"dest\":\"$ADDR\", $STPARS}" --abi Wallet.abi.json --sign wkeys.json

echo "******************** Deploying CT SC    ********************"
ARGS="$(jq -c '' < args.json)"
echo "$ARGS"
tonos-cli deploy --abi CondTran.abi.json --sign ct.keys.json ct.tvc "$ARGS"

echo "******************** Inspecting SC info ********************"
tonos-cli run --abi CondTran.abi.json "$ADDR" getInformation {}

echo "******************** Contract info      ********************"
tonos-cli account "$ADDR"

echo "******************** Get releaseable    ********************"
tonos-cli run --abi CondTran.abi.json "$ADDR" getReleaseable {}

echo "************************************************************"
echo "$ADDR"
