# Overview

[<< Return to documentation index](README.md)

---

## Introduction

Conditional transfer smart contract (CTsc), as the name implies, will allow transferring funds from it subject to some conditions. Broadly speaking, even simple or multisig wallet can be considered a CTsc, however for this competition the task is focused on some different objectives.

Different configurations of such SC may allow to achieve different objectives:

* If external condition is used (release by signed external message or internal message from specific address) an **escrow SC** can be achieved (do not forget for timeouts).
* If contract accepts funds from many different contracts and only releases them when specific amount of collection is done, it is similar to **crowdfunding SC**.
* Moreover, if the release in crowdfunding SC is not done automatically but like in escrow SC (that is, specific amount is required plus message from the controller) it is a **controlled crowdfunding SC** (here a controller, or arbiter, may decide, to send funds further, or to return them to their senders).
* There may be more than one final beneficiary of the collected funds, distributed by fixed amount or percentage or "all remaining" rule, this may be applied to any of the aforementioned contracts.
* The controlling smart contract may be not just a simple wallet, for example, but a multisig wallet, which may allow to decide the outcome not by just one person, but, for example, by majority of votes, or by requiring several persons to confirm the action.
* Timeouts must be defined, so that tons do not get stuck forever in the contract if conditions are never to be fulfilled. 
  * For example, in escrow SC, there should be a timeout, after which sender can poke the contract and get all it's tons back. 
  * In crowdfunding SC there should be a similar timeout for collecting phase (if required amount is not obtained by that time, senders can get their tons back and condition could never be fulfilled afterwards).
  * In controlled crowdfunding SC there should be actually two timeouts: one similar to crowdfunding SC (collecting timeout) and second timeout similar to escrow SC (controlling timeout), that way if either tons are not collected in time or are not permitted to be sent to beneficiaries in time, they may be reclaimed back by senders.

More information on those flavors and their implementation is to be followed in the document.

## Functionality details

The CTsc allows to receive funds and pass them to intended beneficiaries only if some condition is fulfilled. There are several conditions and their sets that allow to build very flexible smart contracts:

* **Minimum amount of collected tons** - this allows to set how much tons have to be on the balance of this smart contract in order to pass collected tons to beneficiaries
* **Maximum amount of collected tons** - this lets ceiling the amount of tons to be collected, any amount that overflows this will be immediately returned to sender
* **Minimum accepted amount** - combats dust by enforcing minimum amount per each message
* **Collection deadline** - enforces that **minimum amount** shall be collected by this time, otherwise all collected tons will become reclaimable by senders
* **Release locktime** - makes it that neither releasing or reclaiming collected tons is not possible until this specified moment (if collection was successful, of course)
* **Release deadline** - by this moment money should be released or refunded, in case it is not done by this moment, next incoming message will trigger the action or change
* **Continuous collection flag** - it is possible to permit (or deny) continuing of collection of tons even after **collection deadline** have passed (if target was reached successfully)
* **Automatic release** - it is possible to specify whether money should be released to beneficiaries or refunded to senders if decision is not made by **release deadline**
* **Controller support** - an external entity may control this contract, either a user with signed external messages, or another smart contract via internal messages. The control is limited to releasing money to beneficiaries or refunding them to senders, if allowed by deadlines and locktime.
* **Multiple beneficiaries support** - it is possible to specify multiple beneficiaries, and what they should receive upon releasing tons: a fixed amount of tons or a percentage against the total balance of contract. There always must be ultimate beneficiary which will receive all remaining tons from the balance of the contract after distributing it to another beneficiaries.
* **Ultimate simplicity for users** - putting money into the contract and reclaiming it does not require any special protons or constructing special messages: contract will automatically receive and account for received funds, and if the contract is in collect phase, will automatically attempt to return any amount that is due to the user, no any commands and special queries required, simple transfer from the wallet should suffice.
* **Ultimate simplicity for controller** - if a wallet is set to be a simple Surf wallet controller can just send text commands by using transfer comment in order to control the contract.
* **Getter methods** - there are several getter methods implemented that allows to easily check some important status information about the contract.



## Some example use cases

### Escrow

This is an example of controlled smart contract that receives money, and external controller decides whether to release money to beneficiary (or beneficiaries) or to refund it to sender.

Lets assume that X tons are to be escrowed. As as safety margin `minTons` should be set to X-E and `maxTons` to X+E (due to possible unexpected storage costs), it is safe to use E value of something like 5 tons. `minAccepted` tons should be set to X or 0. 

`collectDeadline` should be set to zero, while `releaseDeadline` should be set to some reasonable time, after which money will be automatically be reclaimable by sender or passable to beneficiary depending on `autoRelease` value. `releaseLocktime` should be set to zero or reasonable value (money will not be able to be released or refunded before that moment).

Obviously, `controllerAddr` has to be set, with other variables configured correspondingly.

### Automatic crowdfunding

In this case, money is collected until some time and then are automatically released to beneficiaries if raise target is met, or reclaimed by senders if not. `minTons` should be set to raise objective, `maxTons `and `minAccepted` can be set or not depending on requirements. `collectDeadline` should be equal to `releaseDeadline`, and `autoRelease` should be set (to 1). `controllerAddr` of course should be set to zero. 

### Controlled crowdfunding

This use case differs from previous because there is controller (arbiter) that decides whether to pass collected money further or not.

In settings it is almost the same as **Escrow** settings (see above), with the only difference that `minTons`, `maxTons` and `minAccepted` should be set as per crowdfunding requirements, `collectDeadline` should not be zero but set to required value, with `releaseLocktime` be no smaller than `collectDeadline` but no larger than `releaseDeadline` (that is actually a general rule, but in previous examples some of those were zero and as result except to this rule).

`autoRelease` should not be set (set to 0), then if arbiter does not accept releasing money in time, users who invested into crowdfunding would be able to reclaim their money back.

### Custody

It is possible to create a custody smart contract, that holds funds for some time, until receiver confirms that he wants to receive them, if confirmation is not done by that time, sender may recover sent funds. The configuration is similar to **Escrow** contract with the exception that `autoRelease` must be false, and **controller** is the same as **beneficiary**.

### Use your imagination

Using combinations of all those settings it is possible to create interesting contracts. Moreover, contract is not restricted to single beneficiary - it can distribute collected money either with percentages of total sum, fixed sums, or combination of both.

Controller can also be an public key (external controller) - then a signature is required to perform actions, or an smart contract address (internal controller) - then a message from that specified address is required to perform actions. 

And of course do not forget that internal controller can be a complex smart contract as well, such as multisig smart contract, which can allow distribution of responsibility of controlling this smart contract to several parties, such as making them all agree on decision, or require majority of votes. And if parties do not end up with agreement, release_deadline plus auto_release mechanism will take over and refund or release money automatically.

## Further reading

You can return to [the documentation index](README.md) and continue on reading **Deployment** and **Usage and interaction** sections to find out more information about the contract.