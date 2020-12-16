#!/bin/bash -eEx

AID=1111111111111111111111111111111111111111111111111111111111111111

solc CondTran.sol
tvm_linker compile CondTran.code -o "$AID.tvc" --genkey ct.keys.test

tvm_linker test "$AID" --abi-json CondTran.abi.json --abi-method constructor \
  --abi-params "$(cat args.json)" --sign ct.keys.test

tvm_linker test "$AID" --abi-json CondTran.abi.json --abi-method getReleaseable --abi-params {} --trace
