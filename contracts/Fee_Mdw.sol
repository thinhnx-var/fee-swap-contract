// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IPancakeRouter02 {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path, // this is the token path, e.g. BNB -> USDT
        address to, // recipient of the swapped tokens, e.g. msg.sender
        uint deadline
    ) external returns (uint[] memory amounts);
}

contract FeeMiddleware is Ownable {
    address public immutable pancakeRouter;
    uint public feePercentage; // in basis points, e.g., 100 = 1%

    event FeePercentageChanged(uint newFeePercentage);

    constructor(address _router, uint _feePercentage) Ownable(msg.sender){
        require(_router != address(0), "Invalid router address");
        require(_feePercentage <= 10000, "Invalid fee percentage");
        pancakeRouter = _router;
        feePercentage = _feePercentage;
    }

    function setFeePercentage(uint newFeePercentage) external onlyOwner {
        require(newFeePercentage <= 10000, "Fee percentage too high");
        feePercentage = newFeePercentage;
        emit FeePercentageChanged(newFeePercentage);
    }

    function calculateFee(uint amount) public view returns (uint) {
        return amount * feePercentage / 10000;
    }

    function swapTokens(
        address tokenIn,
        address tokenOut,
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        uint deadline
    ) external {
        require(amountIn > 0, "Amount in must be greater than zero");
        require(path.length >= 2, "Invalid path");
        require(path[0] == tokenIn, "Path must start with tokenIn");
        require(path[path.length - 1] == tokenOut, "Path must end with tokenOut");

        // Transfer tokens from user to contract
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

        // Calculate fee
        uint fee = calculateFee(amountIn);

        // Transfer fee to owner
        if (fee > 0) {
            IERC20(tokenIn).transfer(owner(), fee);
        }

        // Calculate amount to swap
        uint amountToSwap = amountIn - fee;
        require(amountToSwap > 0, "Insufficient amount after fee");

        // Approve router to spend the tokens
        IERC20(tokenIn).approve(pancakeRouter, amountToSwap);

        // Call swap
        IPancakeRouter02(pancakeRouter).swapExactTokensForTokens(
            amountToSwap,
            amountOutMin,
            path,
            msg.sender,
            deadline
        );
    }

    // Optional: withdraw functions
    function withdrawToken(address token, uint amount) external onlyOwner {
        IERC20(token).transfer(owner(), amount);
    }

    function withdrawBNB(uint amount) external onlyOwner {
        payable(owner()).transfer(amount);
    }
}