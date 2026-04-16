# 2026-04-SAS-SelfBurn-Exploit

Recreation of a Proof-of-Concept (POC) for the SAS token exploit on BSC

---

## KeyInfo

- Total Lost                        : ~20 WBNB  
- Attacker                          : 0x80eC0E3394860e2Fe9bAFA4a53C1316a067B2628  
- Attack Contract                   : 0x27ABdE2f1757B0704dA5a5870cD85aD09d1b9290  
- Vulnerable Contract               : SAS Token (0xbFa266aEb18D34ef4f8749fc7a1B2064Af3D91c6)  
- Attack Tx                         : 0x878e214a895b057e2f284a084135a6dbe5fe3d696402da6380547a3e5696adc5  
- Chain & Block                     : BSC [90107283]  

---

## Root Cause

- Vulnerability name            : LP Reserve Manipulation via Self-Burn  
- Protocol affected             : SAS Token / PancakeSwap LP (SAS/WBNB)  
- Root cause                    :  
  The SAS token contains a flawed transfer mechanism where sending tokens directly to the LP triggers a **burn from the LP balance**.  

  This burn:
  - Reduces SAS reserves inside the LP  
  - Does NOT reduce WBNB reserves  

  As a result, the pool becomes **imbalanced**, artificially inflating the price of SAS relative to WBNB.

- Broken invariant              :  
  `x * y = k` (constant product AMM invariant)

---

## Attack Path (Step-by-Step)

1. Flashloan 200,000 WBNB from ListaDAO Moolah  
2. Swap WBNB → SAS to acquire ~97% LP liquidity  
3. Trigger large burn by sending SAS directly to LP  
4. Trigger additional burn using minimal transfer  
5. Dump all SAS back to LP for inflated WBNB  
6. Repay flashloan  
7. Keep profit  

---

## Prevention / Mitigation

- Avoid burn logic that affects LP balances  
- Block direct transfers to LP  
- Validate token behavior before listing  

---

## Analysis
 * Post-mortem : Non
 * Twitter Guy : https://x.com/exvulsec/status/2039551675250425986 https://x.com/beacon302/status/2039694349131297002

## Run the POC

```bash
forge test --mp test/2026-04/SAS/SAS_exploit.t.sol -vv
```

## Test Output

```bash
Ran 1 test for test/2026-04/SAS/SAS_exploit.t.sol:SAS_Exploit
[PASS] testExploit() (gas: 1435660)
Logs:
  ------------------------------------------------------------------------
  [START ] Contract Attacker WBNB Balances: 0.000000000000000000
  ------------------------------------------------------------------------
  1. Flashloan Moolah
  2. onMoolah Callback
  3. Create helper 1
  4. Do the transfer to the LP
  This trigger the selfBurn storage accum
  5. Create helper 2
  6. Create helper 3
  0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496
  7. Transfer all WBNB to the attacker contract
  ------------------------------------------------------------------------
  [FINISH] Contract Attacker WBNB Balances: 20.116176879321351048
  ------------------------------------------------------------------------

Suite result: ok. 1 passed; 0 failed; 0 skipped; finished in 434.38ms (4.81ms CPU time)

Ran 1 test suite in 437.16ms (434.38ms CPU time): 1 tests passed, 0 failed, 0 skipped (1 total tests)
```