// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IDexRouter} from "./IDex.sol";

contract Swapper {
    using SafeERC20 for IERC20;

    IDexRouter router; 
    address wETHAddress;

    constructor(address routerV2Address ){
        router = IDexRouter(routerV2Address);
        // wETHAddress = wETH;
    }   

    function swap(address tokenIn, address tokenOut, uint256 amountIn, uint256 minAmountOut, address receiver ) public 
    {
        address sender = msg.sender;

        // uint256 allowance = IERC20(tokenIn).allowance(sender, address(this));
        // require(allowance >= amountIn, "SWAPPER: Not Enough Allowance");

        IERC20(tokenIn).safeTransferFrom(sender, address(this), amountIn);

        IERC20(tokenIn).safeIncreaseAllowance(address(router), amountIn);

        // address[] memory path = new address[](3);
        // path[0]= tokenIn;
        // path[1] = wETHAddress;
        // path[2] = tokenOut;

        address[] memory path = new address[](2);
        path[0]= tokenIn;
        path[1] = tokenOut;

        uint deadline = block.timestamp ;

        router.swapExactTokensForTokens(amountIn, minAmountOut,path,receiver,deadline);
        
    }

    
}