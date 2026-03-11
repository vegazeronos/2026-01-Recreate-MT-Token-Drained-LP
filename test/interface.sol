// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

/**
 * listed interface
 * IMorpho
 * IDodo
 * IPancakeV2Router
 * IAAVE_V3
 * IWETH
 * IUNI_ROUTER_V3
*/

interface IMorpho {
    function flashLoan(address token, uint256 assets, bytes calldata data) external;
}

interface IDodo {
    function flashLoan (uint256 baseAmount, uint256 quoteAmount, address assetTo, bytes calldata data) external;
}

interface IPancakeV2Router {
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function getAmountsOut(uint256 amountIn, address[] calldata path) external view returns (uint256[] memory amounts);
}


interface IPancakeLP {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}

interface IAAVE_V3{
    function flashLoanSimple(address receiver, address token, uint256 amount, bytes memory params, uint16 referralCode) external;
}

interface IUNI_ROUTER_V3{
    struct Params{
        address tokenIn;
        address tokenOut; 
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }
    
    function exactInputSingle(Params calldata params) external returns (uint256);
}

interface IWETH{
    function withdraw(uint256 amount) external;
    function balanceOf(address account) external returns(uint256);
}