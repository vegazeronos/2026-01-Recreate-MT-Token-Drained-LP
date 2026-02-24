# 2026-01-Recreate-MT-Token-Drained-LP
Recreate a POC from MT Token drained hack, which happen on 2026 January. I Got this info from DeFiHackLabs

I recreate it from the POC as stated above for my training, so feel free to comment tho
Here is the link: [MT Token Exploit POC](https://github.com/SunWeb3Sec/DeFiHackLabs/blob/main/src/test/2026-01/MTToken_exp.sol)

Btw, here is the detail of the exploit

// @KeyInfo - Net Pool Loss : ~36,995.244786737651151991 USDT / Gross USDT outflow from pool: ~226,722.244786737651151991 USDT
// Attacker profit: ~36,995.244786737651151991 USDT
// Attacker EOA : 0xe918a1784ceca08e51a1b740f4036fd149339811
// Flashloan Receiver (deployed in tx) : 0xb64f5d49656fae38655ef2e3c2e3768ddb5f3d5c
// Category : oracle manipulation because of fee
// Victim Token : 0x2f3f25046ea518d1e524b8fb6147c656d6722ced (MT)
// Victim Pair : 0xbf4707b7f9f53e3aae29bf2558cb373419ef4d45 (MT/USDT PancakeV2 pair)
// Attack Tx (BSC) : https://bscscan.com/tx/0xc758ab15fd51e713ff8b4184620610a1ac809be06ec374305c32d3b244256a64
//
/**
 * Root cause: Fee Tokens problem
 * 
 * The problem is on the MT Token transfer function, which contain fees.
 * this function "transactionFee" is the main problem
 * 
 * 
 * False Send Fees 3 times on the attack tx
 * From swap()
 * From skim()
 * From sync()
 * 
 */
//
// 
// Post-mortem : https://x.com/nn0b0dyyy/status/2010638145155661942?s=20
// Twitter Alert : https://x.com/TenArmorAlert/status/2010630024274010460?s=20
// Analysis : https://x.com/i/web/status/2010649528198742349


To Run the POC please copy the `MTToken_exploit.t.sol` file to your Foundry project `test` folder
Dont forget to change your RPC URl too

and then run it on terminal with this command
`forge test --mt testExploitLpMtToken -vv`