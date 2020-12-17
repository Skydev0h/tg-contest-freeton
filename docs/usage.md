# Usage and interaction

[<< Return to documentation index](README.md)

---

## Usage

Contract is initialized with all parameters preset from the provided configuration.

Afterwards, transfer(s) to this wallet can be performed by any user. The contract will return a small fixed part of such transfer minus gas and forwarding fees and credit remaining to user's investor balance in contract. There are some situations when message will be just bounced back minus fees:

* Contract's balance plus received tons overflows `maxTons` (extra tons will be returned)
* `collectDeadline` have been reached and `continuousColl` is disabled
* Funds have been released (contract will be `destroy`ed actually after that)
* Message minus fees value is lower than `minAccepted`

In case contract fails, that is condition is not fulfilled in time, or rejection is done by controller, the user can send any (reasonable to pay for processing and forwarding fees) amount of tons to the contract, the contract will look up user's balance and return it with sent tons minus fees. In case user does not have invested balance in the contract, message will be just bounced back.

It may be theoretically possible that for some reason not all funds are distributed when releasing. Releasing funds will set `destroyed` flag, and will try to distribute all funds. Some funds may theoretically bounce (although bounce flag would not be set), therefore if contract survives this (it should not), any message to the `destroyed` contract will cause it sending all it's money to ultimate beneficiary.

---

## Internal messages

Most interaction with the contract is carried out through internal messages. They are used to put ("invest") money in the contract, to reclaim investments when collection or release phases are timed out or is rejected by controller, to release or refund accumulated money by the controller, or to trigger money release if there is no controller but release_locktime is set. Also, the controller may use internal messages to interact with the contract.

### Putting and reclaiming tons

For interaction simplicity of ordinary users with the contract, any message received from a non-controller smart contract will be processed as a funding tons transfer or reclaim request, depending on current state of contract.

* If funding is currently allowed, received amount is credited to the sender's investment balance minus a predefined flat fee, that will be returned minus gas and forwarding fees. In case flat fee is insufficient to cover gas and forwarding fees, user can decide to adjust it's value by passing it in the message, then the alternate value will be used.
* If funding is not allowed and there is no due to be reclaimed the message will be bounced back.
* If there is some amount that is due to by the contract to the sender, message will be bounced back, but that amount will be included along it.
* No fuss and no requirement to construct complex messages, funding and reclaims are dead simple

In response to an ordinary message the contract may answer with some responses:

| Response                  | Description                                                  |
| ------------------------- | ------------------------------------------------------------ |
| (empty)                   | The message have bounced back, possibly value is too low even to process the message. |
| `Auto release`            | The message have triggered the auto release logic.           |
| `Not invested`            | The contract is in reclaim state, but the sender cannot reclaim any tons. |
| `Reclaimed`               | The sender have reclaimed their invested tons, they are attached to the message. |
| `Value is too low`        | The attached value to the message minus gas reserve is lower than `minAccepted`. |
| `Collect deadline passed` | Collect deadline is passed, it is no longer possible to send tons to the contract. |
| `Contract is full`        | Amount of collected funds plus `minAccepted` would be higher than `maxTons`. |
| `Need more ton for gas`   | There is not enough tons attached accounting for gas reserve after adjustment. |
| `Accepted`                | The transfer was accepted and recorded by the contract.      |

`*` By default gas reserve is 1 tons and can be adjusted by calling special method.

### Releasing or refunding collected tons

If a special internal message is received from the controlling smart contract or a signed external message by the controlling key, an action may be performed:

If funds can be released (`minTons` was reached, `collectDeadline` and `releaseLocktime` have passed, `releaseDeadline` has not yet arrived, and, obviously, `controllerAddr` is set) the corresponding message from the controller may:

* initiate refund (internal state flag `canReclaim` will be set to 1), 
* or release money to beneficiaries (money will be immediately released according to beneficiary tables, and contract code and data will be replaced with void)

Enough tons should be provided to pay for processing fees and sending extra back.

**In case `auto_release` is true and `release_deadline` is passed, any internal or external message will attempt processing funds release.**

#### Using internal message comment

In order to release collected funds, if that is allowed, controller may simply send a message containing exactly the comment `Cmd:Release`. If the controller wants to refund collected tons to investors, they may use `Cmd:Reclaim` command to initiate reclaim. The contract may respond with following responses:

| Response                | Description                                                  |
| ----------------------- | ------------------------------------------------------------ |
| `Not yet coll deadline` | Collection deadline have not yet arrived, controller may not yet operate the contract. |
| `Not yet rel locktime`  | Release locktime have not yet arrived, controller may not yet operate the contract. |
| `Rel deadline passed`   | Release deadline have already passed and controller cannot anymore make decisions. They will be carried out by the contract logic. |
| `Already reclaiming`    | A command was received when contract is already in reclaim state. |
| `Target not reached`    | `minTons` target was not yet reached, so release is not possible. |
| `OK:Release`            | `Cmd:Release` command was accepted and tons have been released to beneficiaries. |
| `OK:Reclaim`            | `Cmd:Reclaim` command was accepted and contract have entered reclaim mode. |

As you can see it is very easy to control the contract even without leaving Surf, and it responds with reasonable messages to understand what happened and/or the problem. Very convenient.

---

## External messages

In the Free TON external messages must be sent to a specific ABI function to perform the required operation. As of now there are two functions, `Controller_ReleaseFunds` and `Controller_InitiateReclaim` that are pretty self-descriptive.

To perform that operation the message must be signed by the `controllerAddr` key and it has to be set to the external address corresponding to the key (`-111:...` while initializing).

Those messages will consume contract's balance for processing of refund initiation or money release. Therefore it is important to have a reasonable amount of grams to be sent to ultimate beneficiary, because from it gas processing fees would be deducted.

---

## Increasing gas limit

For very very large contracts it may be possible that default 1 ton gas limit is not enough. The user may opt for increasing the amount of tons reserved for gas by sending this amount as `gasReserve` argument to the `ReserveMoreGas` in the internal message. It may not be lower than default 1 ton reserve.

---

## Inspecting contract state

### Obtaining all possible information

In order to take a look at the current state of the contract you shall use `getInformation` function. It provides information similar to `args.json` file structure (look at **Deployment** section to find out more) with addition of some dynamic state parameters not present in configuration:

`canReclaim` indicates whether it is possible only to reclaim invested funds.

`destroyed` indicates if funds were released, and now all incoming messages would be just transferred to the `ultimateBeneficiary`.

`investorsMap` contains information about which address invested how many funds into this contract.

`controller` contains address of the controller or the public key for external one.

`controllerType` contains `0` for no controller, `1` for external or `2` for internal one.

### Check if contract is reclaiming

You can find out if contract is currently in reclaim state (`canReclaim`) by calling `getIsReclaiming` function.

### Obtaining how many tons can be reclaimed

In order to find out how many funds you can reclaim you should call `getReclaimable` function with passing your address as the `addr` parameter. Zero means no funds to reclaim.

### Simulating release of funds

If you want to see how many funds which beneficiary would receive if the release would be carried out right now you can call `getReleaseable` to find that out. The call would return following items:

`toBens` will contain information about how many nanotons which address would receive.

`toUltBen` will indicate how many nanotons would `ultimateBeneficiary` receive.

`invalid` will contain beneficiaries that have invalid `value` and won't receive tons.

### Simulating release of set amount of tons

Sometimes it may be desirable to estimate how the release would work out if the contract would have a specific amount of tons, for example, after contract was just created it may be reasonable to try to emulate release by providing expected amount of tons (devnet is especially useful for that).

To do that you may call `getReleaseableEmulated` and provide `balance` with the desired amount of nanotons, distribution of which is to be simulated.

The structure of response to this function is absolutely identical to the `getReleaseable` one.

## Further reading

Wow, you have read all the way to here, congratulations!

Well, as of now, that's all folks!

Of course later this manual would be amended with information about interacting with DeBot, using web explorer interface, and such. But as of now, this is the end of manual.

But of course you can return to [the documentation index](README.md) and read any section that you desire if you have missed one and want to get to know it.

Now, have fun using my creation and good luck!