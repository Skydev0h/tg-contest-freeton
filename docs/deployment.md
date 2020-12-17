# Deployment

[<< Return to documentation index](README.md)

---

## Preparation

Currently, to deploy the **C**onditional **T**ransfer Smart Contract you have to use **tonos-cli** tool, but that will absolutely sure change in the future either after being able to deploy and use **CT**SC DeBot when the ecosystem gets ready for them, or, as a fallback solution, deploy mechanics may be integrated into **CT**SC web explorer UI.

First, you would need to install the **tonos-cli** tool (you may already have it installed, since it is needed for many tasks in the network, including multisig and depools), you can find out more at https://github.com/tonlabs/tonos-cli. **As of now the binaries are only provided for Linux,** so if you use Windows or MacOS you would need to build the tool from sources (or use WSL if you use Windows 10). 

Having installed the tool, you may now deploy the contract. In order to do that, you should download files from the https://github.com/Skydev0h/tg-contest-freeton repository (at the very least you would need args.json, CondTran.tvc and CondTran.abi.json files). You may use git tools or just click the green Code button and select Download ZIP. Then you need to extract the archive (if you downloaded it), open terminal (console) and navigate to the downloaded or extracted files dir.

## Configuration

Before deploying the contract you need to configure its parameters. To do the most optimal way is to use supplied [`args.json`](../args.json) file. For short reference you can inspect [`args-annotated.txt`](../args-annotated.txt) file, but to learn about the parameters more thoroughly continue reading.

The default `args.json` file looks like this:

```json
{
  "constraints": {
    "minTons": 0,
    "maxTons": 0,
    "minAccepted": 0,
    "nanoTons": false,
    "collectDeadline": 0,
    "releaseLocktime": 0,
    "releaseDeadline": 0
  },
  "flags": {
    "autoRelease": false,
    "continuousColl": false
  },
  "beneficiariesList": [],
  "ultimateBeneficiary": "0:0000000000000000000000000000000000000000000000000000000000000000",
  "controllerAddr": ""
}
```

You can take a look at [example use-case configs](examples.md) to see some possible configurations of the contract.

### Constraints

The first block called `constraints` defines restrictions and conditions that are enforced.

```json
  "constraints": {
    "minTons": 0,
    "maxTons": 0,
    "minAccepted": 0,
    "nanoTons": false,
    "collectDeadline": 0,
    "releaseLocktime": 0,
    "releaseDeadline": 0
  },
```

| Parameter       | Values | Description                                                  |
| --------------- | ------ | ------------------------------------------------------------ |
| minTons         | 0+     | Minimum amount of tons or nanotons collected required to perform transfer to destination beneficiaries ("release") |
| maxTons         | 0+     | Maximum amount of tons or nanotons that can be collected, overflowing this will return excess or bounce message |
| minAccepted     | 0+     | Minimum amount of tons or nanotons accepted in a message     |
| nanoTons        | true   | minTons, maxTons and minAccepted are specified in nanotons   |
|                 | false  | minTons, maxTons and minAccepted are specified in tons       |
| collectDeadline | \>0    | If `minTons` would not be collected by this time, users will be able to reclaim their tons. Positive values are specified in [unixtime](https://www.epochconverter.com/). |
|                 | =0     | Specifies that there is no collect deadline.                 |
|                 | \<0    | Negative value defines the moment of time that is the set amount of seconds (ignoring the sign) after the contract is deployed. |
| releaseLocktime | \>0    | Specifies the time that needs to be reached for controller to be able to perform release or recall actions. Positive values are specified in [unixtime](https://www.epochconverter.com/). |
|                 | =0     | Specifies that no additional time restriction is on controller actions. |
|                 | \<0    | Negative value defines the moment of time that is the set amount of seconds (ignoring the sign) after the contract is deployed. |
| releaseDeadline | \>0    | If funds are not released or reclaim is not initiated by this time automatic action will be performed depending on `autoRelease` flag value. Positive values are specified in [unixtime](https://www.epochconverter.com/). |
|                 | =0     | Specifies that there is no automatic action deadline.        |
|                 | \<0    | Negative value defines the moment of time that is the set amount of seconds (ignoring the sign) after the contract is deployed. |

Therefore, by configuring those constraints it is possible to attain many different behavior scenarios. Once again, you may take a look at examples for some interesting possible configurations.

### Flags

The second `flags` block sets flags that affect contract behavior.

```json
  "flags": {
    "autoRelease": false,
    "continuousColl": false
  },
```

| Flag          | Value | Description                                                  |
| ------------- | ----- | ------------------------------------------------------------ |
| autoRelease   | false | If `releaseDeadline` is reached reclaim will be initiated, investors would be able to reclaim all their funds. |
|               | true  | If `releaseDeadline` is reached and all other constraints are satisfied any incoming message would distribute funds to the beneficiaries. |
| continousColl | false | Any funds sent after `collectDeadline` would be rejected even if `minTons` target was achieved by that moment. |
|               | true  | Contract would accept funds sent after `collectDeadline` that satisfy another constraints until release or recall event happens. |

### Beneficiaries

The `beneficiaries` block defines who will receive grams if the release funds event is triggered (either automatically or by controller).

```json
  "beneficiariesList": [
    {
      "addr": "0:0000000000000000000000000000000000000000000000000000000000000000",
      "value": 0
    }
  ],
  "ultimateBeneficiary": "0:0000000000000000000000000000000000000000000000000000000000000000",
```

| Parameter           | Value   | Description                                                  |
| ------------------- | ------- | ------------------------------------------------------------ |
| beneficiariesList   | List    | A list (an array) of beneficiaries that would receive some part of funds in case of release event. The inner structure of beneficiaries is defined in next table. |
| ultimateBeneficiary | Address | Specifies an smart contract address that would receive all remaining funds in the contract after distributing them to beneficiaries in case of funds release event. Moreover, when the contract is destroyed (the state the contract stays after the release event) all incoming funds are automatically forwarded to the ultimate beneficiary. |

#### Beneficiaries list

The structure of beneficiaries list is described below. Please pay attention that there are 3 valid possibilities of filling the `value` parameter, please exercise great care when filling it.

| Parameter | Value                         | Description                                                  |
| --------- | ----------------------------- | ------------------------------------------------------------ |
| addr      | Address                       | The address of smart contract that would receive a part of funds that is described by the `value` parameter. |
| value     | \>0                           | The positive value means that this beneficiary would receive exactly `value` nanograms (minus blockchain network transfer fees) |
|           | \>-100000001 and \<0          | The value between -1 and -100,000,000 means that this beneficiary would receive a percent of total collected funds. The percentage is calculated by dividing the value without sign by 1,000,000. |
|           | \>-200000001 and \<-100000000 | The value between -100,000,001 and -200,000,000 means that this beneficiary would receive a percent of the currently remaining funds after distributing them to other beneficiaries. The percentage is calculated by subtracting from the value without sign 100,000,000 and then dividing it by 1,000,000. |
|           | \<-200000000 or 0             | Invalid value, such beneficiary would be skipped during funds distribution. |

It is important to understand that it is possible that during funds distribution the contract may run out of tons. If that happens, then beneficiary would receive smaller amount (all that is still left while distributing) and all other beneficiaries (including ultimate) would not receive funds. As of now it is duty of contract owner to correctly calculate values to make such situation impossible.

I think the value needs some more clarification. Let me present to you some examples of possible values.

| Type     | Value         | Meaning                                                      |
| -------- | ------------- | ------------------------------------------------------------ |
| Absolute | 1,234,567,890 | Exactly 1234567890 nanotons, that is 1.234567890 tons would be sent to the beneficiary. Received sum may be smaller due to network fees. |
|          | 123,456       | Exactly 0.000123456 tons would be sent.                      |
| Invalid  | 0             | Invalid value, beneficiary would be skipped                  |
| Total %  | -25,000,000   | The beneficiary would receive 25% of all collected funds without accounting for where in beneficiaries list it is. |
|          | -54,321,000   | The beneficiary would receive 54.321% of all collected funds. |
| Curr %   | -110,000,000  | The beneficiary would receive 10% of the remaining funds that are still left after distribution to all beneficiaries earlier in the list. |
|          | -123,456,789  | The beneficiary would receive 23.456789% of remaining funds. |
|          | -200,000,000  | The beneficiary would receive all remaining funds. Beneficiaries after it (including the ultimate) would obviously receive no funds. |
| Invalid  | -234,567,890  | Invalid value, beneficiary would be skipped                  |

I hope that examples would clarify possible value meanings. **Of course you shall not specify commas or dots when writing the value, they are merely for your reading convenience.**

### Controller

It is possible to specify a controller, that would be able to decide whether to initiate reclaim or release the funds if that action is allowed by the contract constraints. To do that you need to set the `contractAddr` parameter:

```json
  "controllerAddr": ""
```

This parameter can have following values:

| Type     | Value mask      | Description                                                  |
| -------- | --------------- | ------------------------------------------------------------ |
| None     |                 | There is no controller in this contract. The contract is automatically governed and `releaseDeadline` really should be defined for beneficiaries to be able to ever receive their funds. |
| Internal | 0:...∟or -1:... | The contract is controlled by a smart contract with specified address. A message from specified address can be used to perform controller actions. |
| External | -111:...        | The value after -111: should be a public key, signed messages by which can be used to control the contract and perform controller actions. |

As of now since there is no DeBot interface internal controller can control the contract by sending simple transfer with specified comments. That is, it is possible to set a Surf wallet address as the controller, and it's owner would be able to control contract with simple transfers with specific texts. Cool, yes?

---

**I should additionally note that once contract is deployed all of the parameters above are fixed and cannot be changed no matter what happens for integrity and security reasons.**

## Deploying

In order to deploy the contract first make sure that you have configured contract parameters.

Then, you need to decide what network you want to deploy contract to.

If you want to **perform some testing** with the contract (that is recommended prior to deploying it to main network to verify that it behaves as expected), you should configure `tonos-cli` to use the FreeTON devnet (Rubynet). To do that, run the following command in the console:

```bash
tonos-cli config --url https://net.ton.dev
```

On the other hand, if you want to deploy the contract to the **main network with real TON Crystals**, you can switch to it using the following command:

```bash
tonos-cli config --url https://main.ton.dev
```

**P.S. Make sure that you execute those and all following commands in the folder where the `args.json`, `CondTran.tvc` and `CondTran.abi.json` files are located!**

Afterwards, you need generate a keypair for contract deployment using the command:

```bash
tonos-cli genaddr CondTran.tvc CondTran.abi.json --genkey CondTran.keys.json
```

Afterwards you need to send some tons to the address, that you can observe in the output of the command. For simple deployments 1 tons may be enough, but if many beneficiaries are set you may need 5 tons or more.

You can recall the address by issuing the following command afterwards:

```bash
tonos-cli genaddr CondTran.tvc CondTran.abi.json --setkey CondTran.keys.json
```

Then you should use the following command to verify that tons have actually arrived to the contract:

```bash
tonos-cli account 0:...
```

(You have to enter the address called "Raw address:" in command output)

The account should be found (no error) and have positive balance.

Then, finally, you can deploy the contract. The issue here is that the provided command substitution was tested only on Linux and WSL. It may work on MacOS, and most certainly won't yet work on Windows. The command is:

```bash
tonos-cli deploy --abi CondTran.abi.json --sign CondTran.keys.json CondTran.tvc "$(cat args.json)"
```

If everything works out correctly you will see message that contract was deployed.

## Verifying

To make sure everything worked out correctly and to later inspect state of the contract you can use `getInformation` method in the following manner:

```bash
tonos-cli run --abi CondTran.abi.json "0:..." getInformation {}
```

(Obviously, you need to replace 0:… with address of your contract)

The `getInformation` output should be somewhat similar to the `args.json` file contents that you have set when deploying the contract except that tons would be expanded to nanotons and negative offset times would be populated with the unixtimes.

At any time, you can call `getReleaseable` method to emulate ton distribution as if the contract would be released with current balance:

```bash
tonos-cli run --abi CondTran.abi.json "0:..." getReleaseable {} 
```

It would return how many tons would be distributed to beneficiaries (`toBen`), ultimate beneficiary (`toUltBen`) and which beneficiaries won't receive their part because their configuration is invalid (`invalid`).

If needed to emulate distribution with another balance value, you can call `getReleaseableEmulated` method and supply to it balance parameter specifying how many nanotons you intend to be distributed:

```bash
tonos-cli run --abi CondTran.abi.json "0:…" getReleaseableEmulated '{"balance":"..."}'
```

## Further reading

You can return to [the documentation index](README.md) and continue on reading **Usage and interaction** section to find out how you can interact with the contract that has been deployed using this manual.