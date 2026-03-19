# 2021-XX-Recreate-GooseFinance-EGG-Exploit
Recreate a POC from Goose Finance EGG exploit on 12 March 2026.

## KeyInfo

- Total Lost                        : ~8400 USD

- Attacker                          : [0x1E959Ce51E70FF93278c470Bf05a0f09b3c850de](https://bscscan.com/address/0x1E959Ce51E70FF93278c470Bf05a0f09b3c850de)

- Attack Contract                   : [0xd7E9763D79Eb9011e518129c79455E7eA65e0Cbf](https://bscscan.com/address/0xd7E9763D79Eb9011e518129c79455E7eA65e0Cbf)

- Vulnerable Contract               :

  - [VaultChef](https://bscscan.com/address/0x3F648151f5D591718327aA27d2EE25edF1b435D8)
  - [StrategyGooseEGG](https://bscscan.com/address/0x09806632AAbc99ae43a8644f336F38f9F559B26B)
  - [MasterChef](https://bscscan.com/address/0xe70E9185F5ea7Ba3C5d63705784D8563017f2E57)

- Attack Tx                         : [0x86efdf5b45ee833e696be15bddf0b60f6c449f73a45e39edd4838d9ece316223](https://app.blocksec.com/phalcon/explorer/tx/bsc/0x86efdf5b45ee833e696be15bddf0b60f6c449f73a45e39edd4838d9ece316223)


## Root Cause

- Vulnerability name            : Reward inflation via repeated deposit/withdraw (VaultChef)

- Protocol affected             : [VaultChef](https://bscscan.com/address/0x3F648151f5D591718327aA27d2EE25edF1b435D8) / Goose Finance

- Root cause                    : **TODO — confirm from on-chain trace.**

  From the contract logic, the attacker flash-borrows a large amount of EGG tokens via two nested PancakeSwap flash swaps, then calls `vaultChef.deposit()` followed by `vaultChef.withdraw()` **twice in sequence** on PID 60. This likely manipulates the pending reward or share accounting inside `StrategyGooseEGG` between the two deposit/withdraw cycles, allowing the attacker to extract more EGG than deposited.

- Broken invariant              : Amount user withdrawal never exceed the amount they deposited plus legitimate rewards.

- Attack path (step-by-step)    :
  1. Flash swap EGG from `LP_BUSD_EGG` (PancakeSwap)
  2. Inside `pancakeCall` (0x1): flash swap EGG from `LP_WBNB_EGG` (nested)
  3. Inside `pancakeCall` (0x2): `vaultChef.deposit(PID=60, amount)` [1st deposit]
  4. `vaultChef.withdraw(PID=60, type(uint256).max)` [1st withdraw]
  5. `vaultChef.deposit(PID=60, amount)` [2nd deposit]
  6. `vaultChef.withdraw(PID=60, type(uint256).max)` [2nd withdraw — inflated]
  7. Repay `LP_WBNB_EGG` flash swap
  8. Repay `LP_BUSD_EGG` flash swap
  9. Dump EGG → BUSD → WBNB, unwrap WBNB → BNB, transfer profit to EOA

- Prevention / mitigation       : **TODO — confirm from root cause.**

  Likely: apply the Checks-Effects-Interactions (CEI) pattern inside the Strategy — update share/reward state before any external call. Alternatively add a same-block deposit/withdraw guard to prevent atomic manipulation.


## Run the POC

To run the POC please copy the `GooseEgg_exploit.t.sol` file to your Foundry project `test` folder.
Don't forget to change your RPC URL too.

Then run it on terminal with this command:

```bash
forge test --mp test/2026-03/GooseEgg/GooseEgg_exploit.t.sol -vv
```


## Test Output

> **TODO** — paste `forge test` output here