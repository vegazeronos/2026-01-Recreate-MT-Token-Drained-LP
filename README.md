# README
Hi there !
Welcome to my learning repository...


in this repo, you can find my training learning to create POC base on exploit that happen, all of it is EVM (for now)

# Goals
I tried to learn exploit by become the hacker POV and see how the exploit can be done. I think its more fun in this way rather than read long reports

Every test case i divided by folder on date, which you can found any exploit that happen on that month.
e.g on 2026-01/MTToken_exploit --> this means that on 2026 January, there's an exploit on MT Token

# How to read the repo
On this repo, you will find lots of exploit thaat i recreate(as for now only 2), and I explain why it is happen on the Readme.md
I also explain what happen on the attack on readme for each exploit

If you want to rerun the repo, its easy, just clone this repo, and run from test folder `forge test --mt testExploitLpMtToken -vv`, and the exploit should begin. Dont forget to change the `RPC Url` on foundry.toml


# References
I learn this exploit from this cool repo : [DeFiHackLabs](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main)