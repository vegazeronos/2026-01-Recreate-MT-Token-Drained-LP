// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;
/*

/**
 * ##Author                         : @haveashib
 * 
 * ##KeyInfo - Total Lost           : ~999M US$
 * Attacker                         : 0xcafebabe
 * Attack Contract                  : 0xdeadbeef
 * Vulnerable Contract              : 0xdeadbeef
 * Attack Tx                        : 0x123456789
 * Type Vulnerability               : Reentrancy / ...
 * 
 * ##Root Cause : 
 * 1. Vulnerability name            :
 * 2. Protocol affected             :
 * 3. Root cause                    :
 * 4. Broken invariant              :
 * 5. Attack path (step-by-step)    :
 * 6. Prevention / mitigation       :
 * 
 * ##Analysis
 * Post-mortem : https://www.google.com/
 * Twitter Guy : https://www.google.com/
*/
 

/*

import {Test, console2} from "forge-std/Test.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import "../../interface.sol"; // <-- often used interface stored here

uint256 constant FORK_BLOCK = 42832267 - 1;

address constant EOA_ATTACKER = 0x79265e89FeAf7E971DEc75db1432795e6bd4b466;

contract ContractTest is Test {
    
    function setUp() public {
        vm.createSelectFork("base", FORK_BLOCK);

        //label
        vm.label(EOA_ATTACKER, "EOA Attacker");

        logBalances("[START]", EOA_ATTACKER);
        logBalances("[FINISH]", EOA_ATTACKER);
    }
    
    function testExploit() public {
        //vm.startPrank(alice);
        //vm.stopPrank();
    }

    // INTERNAL FUNCTION

    function logBalances(string memory tag, string memory name, address recipient) internal{
        console2.log("------------------------------------------------------------------------");
        emit log_named_decimal_uint(string.concat(tag," ", name ," USDC Balances"), USDC.balanceOf(recipient), USDC.decimals());
        console2.log("------------------------------------------------------------------------");
    }
}

*/