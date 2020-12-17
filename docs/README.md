# Documentation

This documentation is subject to change as contract evolves over time.

I expect both the deployment and usage parts drastically change as FreeTON evolves over time.

## Overview

Conditional transfer smart contract (CT SC), as the name implies, will allow transferring funds from it subject to some conditions. Broadly speaking, even simple or multisig wallet can be considered a CT SC, however for this competition the task is focused on some different objectives.

You can find out more about contract features and logic [at this page](overview.md).

## Deployment

As of now to deploy the smart contract at the very least you require the [tonos-cli](https://github.com/tonlabs/tonos-cli) tool.

The deployment process is explained in more detail [at this dedicated page](deployment.md).

If you want to be extra paranoid you may want to recompile the contract yourself, then you would need [TON Solidity compiler](https://github.com/tonlabs/TON-Solidity-Compiler) and [TVM Linker](https://github.com/tonlabs/TVM-linker) tools. You can learn more about writing and compiling smart contracts in [this official guide](https://docs.ton.dev/86757ecb2/p/950f8a-write-smart-contract-in-solidity). Some intricacies about setting up tooling and compiling contracts are outlined there.

## Usage and interaction

Depending on how the contract is deployed and configured there are different ways how to interact with it.

This guide explains how you can interact with the on-chain deployed smart contract, inspect it and send commands to it.

Please follow [this link](usage.md) if you would like to know more about interacting with CT SC.