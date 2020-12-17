# Examples

[<< Return to documentation index](README.md)

---

## Introduction

This document provides examples of some possible configurations of the contract and what contents of `args.json` you may use to achieve such objective.

This is by no means a complete list of possible configurations of the contract, merely being a hint to activate your creativity. By adjusting configuration parameters and chaining this contract (both in and out) with other smart contracts you can achieve unthinkable results.

In order to understand how to use the provided configurations please read the **Deployment** section of the manual, it surely will be useful!

Now, let's get started.

#### Example: Escrow contract

To create an escrow contract controlled with external messages you can use a configuration similar to the following one:

```json
{
  "constraints": {
    "minTons": 495,
    "maxTons": 505,
    "minAccepted": 500,
    "nanoTons": false,
    "collectDeadline": -3600,
    "releaseLocktime": 0,
    "releaseDeadline": -3600
  },
  "flags": {
    "autoRelease": false,
    "continuousColl": false
  },
  "beneficiariesList": [],
  "ultimateBeneficiary": "-1:0000000000000000000000000000000000000000000000000000000000000000",
  "controllerAddr": "-111:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
}
```

Creation of this contract requires possession of the public key, that can be provided by the arbiter.

The contract requires at least 495 tons for release, but no more than 505. A single message must carry at least 500 tons. For this example the deadlines are set in a hour from the script execution moment, therefore if controller does not confirm release by that time, funds will become reclaimable. 

**Note** that beneficiary in this example is a -1:0...0 contract, so executing this command as is would create a contract that would burn funds. Moreover, you need to fill in the public key part into `controllerAddr`.

You may consider it be easier to just specify a controller wallet address to use internal msg controller.

#### Example: Automatic crowdfunding contract (positive)

To create an crowdfunding contract that would automatically send money to beneficiary as soon as required target is achieved, you can use something like this:

```json
{
  "constraints": {
    "minTons": 1000,
    "maxTons": 0,
    "minAccepted": 10,
    "nanoTons": false,
    "collectDeadline": 0,
    "releaseLocktime": 0,
    "releaseDeadline": 1
  },
  "flags": {
    "autoRelease": true,
    "continuousColl": false
  },
  "beneficiariesList": [],
  "ultimateBeneficiary": "0:0000000000000000000000000000000000000000000000000000000000000000",
  "controllerAddr": ""
}
```

This contract would automatically transfer all collected funds to the beneficiary as soon as required sum is collected in the contract (with next incoming internal message after it). Minimal accepted value is necessary to prevent potential dust attacks. Also release deadline is set to unixtime 1 and auto release is enabled, therefore as soon as required sum is collected it would be automatically released.

#### Example: Automatic timed crowdfunding (with deadlines)

This contract differs in that way, that sum must be collected by some moment, otherwise it would be reclaimed by senders.

```json
{
  "constraints": {
    "minTons": 1000,
    "maxTons": 0,
    "minAccepted": 10,
    "nanoTons": false,
    "collectDeadline": -3600,
    "releaseLocktime": 0,
    "releaseDeadline": -3600
  },
  "flags": {
    "autoRelease": true,
    "continuousColl": false
  },
  "beneficiariesList": [],
  "ultimateBeneficiary": "0:0000000000000000000000000000000000000000000000000000000000000000",
  "controllerAddr": ""
}
```

This way, if 1000 tons are collected in hour, they will be released to beneficiary after this hour passes. Otherwise, they will be reclaimable by their senders and never be released.

#### Example: Controlled crowdfunding

For this example, we have a crowdfunding that must both reach some goal by set moment, later be accepted by a controller from some contract (maybe even multisig for voting) and this has minimum and maximum clearance time too. Lets get started:

```json
{
  "constraints": {
    "minTons": 1000,
    "maxTons": 2000,
    "minAccepted": 10,
    "nanoTons": false,
    "collectDeadline": -3600,
    "releaseLocktime": -7200,
    "releaseDeadline": -10800
  },
  "flags": {
    "autoRelease": false,
    "continuousColl": false
  },
  "beneficiariesList": [],
  "ultimateBeneficiary": "-1:0000000000000000000000000000000000000000000000000000000000000000",
  "controllerAddr": "-1:3333333333333333333333333333333333333333333333333333333333333333"
}
```

This complex example involves many settings used. First of all, it defines minimum collect target as 1000 tons, maximum collected as 2000 tons and minimum deposit value of 10 tons. Afterwards, it defines three time barriers: in 1 hour, collection phase will end, and funds would be refunded if they did not meet required minimum amount, in 2 hours release lock would fall, before that moment controller would not be able to neither release funds or allow reclaiming, and, finally, in 3 hours if action was not taken by controller by this time funds would become reclaimable automatically. For this example, contract can be controlled by a -1:3...3 smart contract, and beneficiary is -1:0...0 one.

#### Example: Multiple beneficiaries

Lets reconsider the first example, and mix in some additional beneficiaries:

```json
{
  "constraints": {
    "minTons": 495,
    "maxTons": 505,
    "minAccepted": 500,
    "nanoTons": false,
    "collectDeadline": -3600,
    "releaseLocktime": 0,
    "releaseDeadline": -3600
  },
  "flags": {
    "autoRelease": false,
    "continuousColl": false
  },
  "beneficiariesList": [
    {
      "addr": "-1:3333333333333333333333333333333333333333333333333333333333333333",
      "value": 20000000000
    },
    {
      "addr": "-1:2222222222222222222222222222222222222222222222222222222222222222",
      "value": -20000000
    }
  ],
  "ultimateBeneficiary": "-1:0000000000000000000000000000000000000000000000000000000000000000",
  "controllerAddr": "-111:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
}
```

This example would cause release phase to be as following:

* Exactly 20 tons would be sent to first beneficiary (-1:3...3)
* 10% of all collected sum (about 50 tons) would be sent to second one (-1:2...2)
* Finally, all remaining sum would be sent to ultimate beneficiary (-1:0...0)

It should be noted carefully that percentage is calculated from total sum, not remaining one. Therefore, creator should be careful so that all sums fit if only minimum sum is collected.

#### Example: Custody

For this example, money is sent to this SC, that holds it for some time, and receiver must confirm that he wants to receive that money in time. Otherwise, sender will be able to reclaim sent money.

```json
{
  "constraints": {
    "minTons": 495,
    "maxTons": 505,
    "minAccepted": 500,
    "nanoTons": false,
    "collectDeadline": -3600,
    "releaseLocktime": 0,
    "releaseDeadline": -3600
  },
  "flags": {
    "autoRelease": false,
    "continuousColl": false
  },
  "beneficiariesList": [],
  "ultimateBeneficiary": "-1:0000000000000000000000000000000000000000000000000000000000000000",
  "controllerAddr": "-1:0000000000000000000000000000000000000000000000000000000000000000"
}
```

The configuration is almost similar to **Escrow** with the exception that **ultimate beneficiary** and **controller** are actually the same, and **autoRelease** must be set to false for logical reasons.

---

## Further reading

Those were just some but most prominent examples of what you can do with **CT**SC by configuring it differently. You can return to [the documentation index](README.md) and continue on reading **Deployment** section to find out how you can use the presented configs on this page on practice, and invent your own.