# 2026-03-Recreate-Wukong-Exploit
Recreate a POC from Wukong exploit, which happen on 12th March 2026. 

## KeyInfo 

- Total Lost                        : ~39k USD

- Attacker                          : [0x13Be1Ae7C8413cC95f3566e9393c618D29965Ac8](https://bscscan.com/address/0x13be1ae7c8413cc95f3566e9393c618d29965ac8)

- Attack Contract                   : [Self Destructed Attack Contract](https://bscscan.com/address/0xddb8fd9441242b25f401096536d6ef83afa9101f)

- Vulnerable Contract               : 
  
- [Wukong Stake Proxy](https://bscscan.com/address/0x07d398c888c353565cf549bbee3446791a49f285)

- Attack Tx                         : [Phalcon Attack Trace](https://app.blocksec.com/phalcon/explorer/tx/bsc/0x79467533d4d1f332df846dc78c16fe319cd1d3a1a0f01545b4cdd7a2d3a71d22?line=26)


## Root Cause

- Vulnerability name            : Reentrancy
  
- Protocol affected             : [Wukong Stake Proxy](https://bscscan.com/address/0x07d398c888c353565cf549bbee3446791a49f285)
  
- Root cause                    : No Protection on Reentrancy while unstaking.

on the implementation part of the contract is this [StakingUpgradeable](https://bscscan.com/address/0xd828e972b7fc9ad4e6c29628a760386a94cfdeda#code).
Altho the proxy is not verify yet, the implementation is verified and we can find the code there.

On my POC, it explained that the cause of this exploit is because of Reentrancy on `unstake()` which the attacker exploit it to reenter the unstake amount and make the LP sent the unstake amount as much as it can.


```solidity
function unstake() external whenNotPaused {
        .
        .
        .
        .
        // 返回BNB给用户
        // payable(msg.sender).transfer(bnbReceived);
        (bool success,) = payable(msg.sender).call{value: bnbReceived}("");
        require(success, "Failed to transfer BNB");

        // 更新质押状态
@>      stakeInfoList[index].isStaking = false;
        stakeInfoList[index].startTime = 0;
        stakeInfoList[index].amount = 0;
        stakeInfoList[index].lpAmount = 0;
        emit Unstake(msg.sender, bnbReceived, stakeInfoList[index].lpAmount);
    }
```

`isStaking = false` is updated AFTER the external call to the msg.sender, which make the attacker can do reenter the contract and make the unstaking as much as it can to drained the pool.
  
- Broken invariant              : unstake amount > stake amount
  
- Attack path (step-by-step)    : Stake 2BNB -> Unstake 2BNB -> Reenter the Unstake until the LP is drained -> Transfer BNB to the EOA
  
- Prevention / mitigation       : Use CEI 

```diff
function unstake() external whenNotPaused {
        
+       // CHECK
        require(hasStaked(msg.sender), "No stake found");
        uint256 index = userStakeIndex[msg.sender];
        require(stakeInfoList[index].isStaking, "Already unstaked");

+       // EFFECT 
        // 更新统计
        totalStakeAmount -= stakeInfoList[index].amount;
        totalStakeLpAmount -= stakeInfoList[index].lpAmount;

        // 移除LP
        uint256 tokenAmountBefore = stakingToken.balanceOf(address(this));
        uint256 bnbAmountBefore = address(this).balance;
        router.removeLiquidityETH(
            address(stakingToken), stakeInfoList[index].lpAmount, 0, 0, address(this), block.timestamp
        );
        uint256 bnbReceived = address(this).balance - bnbAmountBefore;
        uint256 tokenReceived = stakingToken.balanceOf(address(this)) - tokenAmountBefore;
        // 销毁所有代币
        if (tokenReceived > 0) {
            try ITokenWhiteList(address(stakingToken)).WHITE_LIST(msg.sender) returns (bool isWhitelisted) {
                if (isWhitelisted) {
                    // 如果是白名单地址，转账给地址本身
                    IERC20(address(stakingToken)).transfer(msg.sender, tokenReceived);
                } else {
                    // 如果不是白名单地址，安全销毁
                    IERC20(address(stakingToken)).transfer(address(0xdEaD), tokenReceived);
                }
            } catch {
                // 如果调用白名单检查失败，安全销毁
                IERC20(address(stakingToken)).transfer(address(0xdEaD), tokenReceived);
            }
        }
        // 返回BNB给用户
        // payable(msg.sender).transfer(bnbReceived);
-       (bool success,) = payable(msg.sender).call{value: bnbReceived}("");
-       require(success, "Failed to transfer BNB");

        // 更新质押状态
        stakeInfoList[index].isStaking = false;
        stakeInfoList[index].startTime = 0;
        stakeInfoList[index].amount = 0;
        stakeInfoList[index].lpAmount = 0;
        emit Unstake(msg.sender, bnbReceived, stakeInfoList[index].lpAmount);

+       // INTERACTION
+       (bool success,) = payable(msg.sender).call{value: bnbReceived}("");
+       require(success, "Failed to transfer BNB");
    }
```


## Run the POC

To Run the POC please copy the `Wukong_exploit.t.sol` file to your Foundry project `test` folder
Dont forget to change your RPC URl too

and then run it on terminal with this command
`forge test --mp test/2026-03/WUKONG/WUKONG_exploit.t.sol -vv`

```md
Ran 1 test for test/2026-03/WUKONG/WUKONG_exploit.t.sol:Wukong_Exploit
[PASS] test_wukongExploit() (gas: 23110099)
Logs:
  ------------------------------------------------------------------------
  [START] EOA Attacker BNB Balances: 0.000000000000000000
  [START] EOA Attacker WBNB Balances: 0.000000000000000000
  ------------------------------------------------------------------------
  ------------------------------------------------------------------------
  [START] Victim LP BNB Balances: 0.000000000000000000
  [START] Victim LP WBNB Balances: 124.839012193772044721
  ------------------------------------------------------------------------
  |
  1. Create Attack Contract to do stake() and unstake()
  |
  2. Borrow 2,01 WBNB for this contract
  |
  3. On pancakeCall(), convert WBNB into BNB to stake
  |
  4. After stake, do the unstake()
  |
  5. On unstake(), this contract will reenter until the balance of the contract is done for / out of gas
  |
  6. After done the reenter, we deposit back the BNB to WBNB so we can pay back the borrowed money
  |
  7. Selfdestruct to send the BNB to the first contract.
  |
  8. Repeat step 2 - 8 until there's no left one the LP
  |
  2. Borrow 2,01 WBNB for this contract
  |
  3. On pancakeCall(), convert WBNB into BNB to stake
  |
  4. After stake, do the unstake()
  |
  5. On unstake(), this contract will reenter until the balance of the contract is done for / out of gas
  |
  6. After done the reenter, we deposit back the BNB to WBNB so we can pay back the borrowed money
  |
  7. Selfdestruct to send the BNB to the first contract.
  |
  8. Repeat step 2 - 8 until there's no left one the LP
  |
  9. Last thing, we want to send this BNB to the EOA through selfdestruct
  |
  ------------------------------------------------------------------------
  [FINISH] EOA Attacker BNB Balances: 93.989547999999999998
  [FINISH] EOA Attacker WBNB Balances: 0.000000000000000000
  ------------------------------------------------------------------------
  ------------------------------------------------------------------------
  [FINISH] Victim LP BNB Balances: 0.000000000000000000
  [FINISH] Victim LP WBNB Balances: 29.639012193772044723
  ------------------------------------------------------------------------

Suite result: ok. 1 passed; 0 failed; 0 skipped; finished in 4.39s (3.61s CPU time)

Ran 1 test suite in 4.41s (4.39s CPU time): 1 tests passed, 0 failed, 0 skipped (1 total tests)
```