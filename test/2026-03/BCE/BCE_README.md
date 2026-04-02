# 2026-03-Recreate-BCE-Token-Exploit

Recreate a POC from BCE exploit on BSC, which happened on block 88215293.

---

## KeyInfo

- Total Lost                        : ~800,000 USD

- Attacker                          : 0x9f7EABD7C3538bA6B9D10Eede63712c0EccE6D69

- Attack Contract                   : 0xaf7f22831d1ec86d24be51a1760b04ad4b58e9eb

- Vulnerable Contract               :

  - BCE Token                       : 0xcdb189D377AC1cF9D7B1D1a988f2025B99999999
  - Pancake LP (USDT/BCE)           : 0xca23E8d408d769661CB480a3fd45d6Be370c45f7

- Attack Tx                         :

  - Attack Tx 1                     : 0x37243080c54d63d78a3246a34f46c8cb4e4eb0ff1bb1b9f77fd768e0fe024630
  - Attack Tx 2                     : 0x85ac5d15f16d49ae08f90ab0e554ebfcb145712342c5b7704e305d602146d452

---

## Root Cause

- Vulnerability name            : Burn Mechanism Flaw

- Protocol affected             : BCE token / PancakeSwap BCE-USDT LP

- Root cause                    :

  The BCE token implements a burn mechanism for non-whitelisted addresses.  
  However, this burn logic is flawed and unintentionally **removes BCE tokens from the LP reserve** during transfer token from non whitelisted.

```javascript
  function _update(address from, address to, uint256 value) internal override {
        .
        .
        .
            if (lastBuyTime[to] == 0) lastBuyTime[to] = block.timestamp;
            if (from != address(this)) {
                uint256 today = block.timestamp / 1 days;
                if (lastBurnPool < today) {
                    super._update(_uniswapV2Pair, address(0), reserveBCE / 100);
                    IUniswapV2Pair(_uniswapV2Pair).sync();
                    lastBurnPool++;
                }
                if (scheduledDestruction > 0) {
                    super._update(_uniswapV2Pair, address(0), scheduledDestruction);
                    IUniswapV2Pair(_uniswapV2Pair).sync();
                    scheduledDestruction = 0;
                }
                if (value == 0.3 ether) {
                    require(reserveBCE > 0, 'no liquidity');
                    require((balanceOf(from) * reserveUSDT) / reserveBCE >= 200 ether, 'lt 200u');
                    R.notifyTransfer(from, to);
                }
@>              if (!whiteList[from]) {
@>                  super._update(from, address(0), value / 2);
@>                  value /= 2;
@>              }
        .
        .
        .
    }
```

  By repeatedly interacting with the LP via flash swaps, the attacker is able to:

  - Reduce BCE reserve inside the pool
  - Break the price invariant of the AMM
  - Artificially inflate the price of BCE relative to USDT

  This allows the attacker to swap BCE back into **excessive USDT**, effectively draining the pool.

- Broken invariant              : actualTokenBalance != recordedReserve

  Due to the BCE burn mechanism, the amount of tokens received by the LP
  is lower than expected during transfers. This causes the internal reserve
  accounting of the AMM to become inconsistent with reality.

  As a result, the pricing formula operates on corrupted reserves,
  allowing the attacker to extract excess value from the pool.

---

## Attack Path (Step-by-step)

**Step 1 — Multi-asset flash loans (ListaDAO Moolah)**

1. Flash loan USDT
2. Nested flash loan BTCB
3. Nested flash loan WBNB

---

**Step 2 — Use Venus to amplify capital**

1. Supply:
 - WBNB → vWBNB
 - BTCB → vBTC
2. Enter Venus markets
3. Borrow massive USDT (`vUSDT`)

---

**Step 3 — Prepare attack environment**

1. Approve tokens to Pancake Router
2. Deploy Helper contract
3. Transfer USDT to Helper contract

---

**Step 4 — First flash swap (manipulate LP)**

1. Flash swap large amount of BCE from LP
2. Trigger BCE burn mechanism (non-whitelisted path)
3. BCE reserve inside LP decreases abnormally
4. Drain BCE from helper back to attacker

---

**Step 5 — Swap inflated BCE → USDT**

1. Due to reduced BCE reserve, price becomes distorted
2. Swap BCE into large amount of USDT
3. LP state becomes increasingly imbalanced

---

**Step 6 — Second flash swap (final drain)**

1. Repeat flash swap BCE
2. Further manipulate LP reserves
3. Drain remaining BCE and USDT liquidity

---

**Step 7 — Final extraction**

1. Transfer all USDT from helper back to main contract
2. Swap remaining BCE → USDT
3. Attacker now holds majority of pool USDT

---

**Step 8 — Repay all loans**

1. Repay Venus borrow
2. Redeem collateral (WBNB, BTCB)
3. Repay all flash loans (WBNB, BTCB, USDT)

---

**Step 9 — Profit**

Remaining USDT is transferred to attacker EOA.

---

## Exploit Intuition

1. Abuse flawed burn mechanism  
2. Reduce BCE liquidity in LP  
3. Break AMM pricing  
4. Swap manipulated asset for real USDT  
5. Drain pool  

---

## Prevention / Mitigation

- Do **not apply burn mechanics directly on LP transfers**
- Exclude LP addresses from burn logic
- Validate tokenomics interactions with AMM pools
- Add invariant checks to prevent reserve manipulation
- Consider using virtual balances or protected accounting for LP interactions

---

## Analysis

- Post-mortem : none

- Twitter     :

- https://x.com/DefimonAlerts/status/2036009924195418497
- https://x.com/ma1fan/status/2036017540066050309
- https://x.com/chrisdior777/status/2036016273088229796

---

## Run the POC

To run the POC, copy the test file into your Foundry project:

Then run:

```bash
forge test --mp test/BCE/BCE_exploit.t.sol -vv
```

## Test Output

```bash
Ran 1 test for test/2026-03/BCE/BCE_exploit.t.sol:BCEExploit
[PASS] test_bceExploit() (gas: 3193274)
Logs:
  ------------------------------------------------------------------------
  [START ] EOA Attacker USDT Balance: 0.000000000000000000
  [START ] Attack Contract USDT Balance: 26.542161622221038197
  [START ] Victim Contract USDT Balance: 800009.324167400508037529
  [START ] Victim Contract BCE  Balance: 7920105.380000000000000000
  ------------------------------------------------------------------------
  |
  1. Flash loan 8942561534383223143548705 USDT from ListaDAO Moolah
  |
  2. Flash loan 416548084543597106310 BTCB from ListaDAO Moolah (nested)
  |
  3. Flash loan 375209737185690989900050 WBNB from ListaDAO Moolah (nested)
  |
  4. Approve WBNB -> vWBNB, BTCB -> vBTC, enter Venus markets
  |
  5. Borrow 114560942280156224846440409 vUSdt from Venus
  |
  6. Approve USDT -> Router v2 and BCE -> Router v2
  |
  6b. Transfer USDT to helper contract and deploy it
  LP balance BCE: 7920105380000000000000000
  |
  7. Flash swap BCE from Cake-LP (round 1)
  |
  8. Flash swap BCE from Cake-LP (round 2)
  |
  9. Drain BCE + USDT from helper contract back to receiver
  |
  9b. Swap remaining BCE -> USDT via PancakeSwap Router v2
  |
  9c. Repay vUSdt borrow and redeem vWBNB + vBTC
  |
  9d. Repay WBNB flash loan to ListaDAO Moolah
  |
  10. Repay BTCB flash loan to ListaDAO Moolah
  |
  11. Repay USDT flash loan to ListaDAO Moolah
  ------------------------------------------------------------------------
  [FINISH] EOA Attacker USDT Balance: 0.000000000000000000
  [FINISH] Attack Contract USDT Balance: 800035.866329022728816220
  [FINISH] Victim Contract USDT Balance: 0.000000000000259506
  [FINISH] Victim Contract BCE  Balance: 1412962.214473276250006675
  ------------------------------------------------------------------------

Suite result: ok. 1 passed; 0 failed; 0 skipped; finished in 651.84ms (17.91ms CPU time)

Ran 1 test suite in 659.67ms (651.84ms CPU time): 1 tests passed, 0 failed, 0 skipped (1 total tests)
```