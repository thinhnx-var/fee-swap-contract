// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IPancakeRouter02 {
    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);

    function swapExactTokensForETH(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function WBNB() external pure returns (address);
}

contract FeeMiddleware is Ownable {
    IPancakeRouter02 public immutable pancakeRouter;
    uint public feeBasisPoints; // Fee in basis points (e.g., 100 = 1%)
    uint constant BASIS_POINTS = 10000; // 100% = 10000 basis points

    event SwappedBNBToToken(address indexed user, address token, uint bnbIn, uint tokenOut, uint fee);
    event SwappedTokenToBNB(address indexed user, address token, uint tokenIn, uint bnbOut, uint fee);
    event FeeUpdated(uint newFeeBasisPoints);

    constructor(address _pancakeRouter, uint _initialFeeBasisPoints) Ownable(msg.sender){
        require(_pancakeRouter != address(0), "Invalid router address");

        pancakeRouter = IPancakeRouter02(_pancakeRouter);
        feeBasisPoints = _initialFeeBasisPoints;
    }

    // Admin function to set fee percentage
    function setFee(uint _feeBasisPoints) external onlyOwner {
        require(_feeBasisPoints <= BASIS_POINTS, "Fee exceeds 100%");
        feeBasisPoints = _feeBasisPoints;
        emit FeeUpdated(_feeBasisPoints);
    }

    // Swap $BNB to any Token, deduct fee from input $BNB
    function swapBNBToToken(
        address token,
        uint amountOutMin,
        uint deadline
    ) external payable {
        require(msg.value > 0, "No BNB sent");
        require(token != address(0), "Invalid token address");
        require(feeBasisPoints < BASIS_POINTS, "Fee too high");

        // Calculate fee and amount to swap
        uint fee = (msg.value * feeBasisPoints) / BASIS_POINTS;
        uint amountToSwap = msg.value - fee;

        // Define swap path: WBNB -> Token
        address[] memory path = new address[](2);
        path[0] = pancakeRouter.WBNB();
        path[1] = token;

        // Perform swap
        uint[] memory amounts = pancakeRouter.swapExactETHForTokens{value: amountToSwap}(
            amountOutMin,
            path,
            msg.sender,
            deadline
        );

        // Send fee to owner
        (bool sent, ) = owner().call{value: fee}("");
        require(sent, "Fee transfer failed");

        emit SwappedBNBToToken(msg.sender, token, msg.value, amounts[1], fee);
    }

    // Swap any Token to $BNB, deduct fee from received $BNB
    function swapTokenToBNB(
        address token,
        uint amountIn,
        uint amountOutMin,
        uint deadline
    ) external {
        require(amountIn > 0, "No tokens sent");
        require(token != address(0), "Invalid token address");
        require(feeBasisPoints < BASIS_POINTS, "Fee too high");  // Add this check to be consistent with swapBNBToToken

        // Check token balance of sender before transfer
        uint256 beforeBalance = IERC20(token).balanceOf(address(this));

        // Transfer tokens from user to contract
        bool transferred = IERC20(token).transferFrom(msg.sender, address(this), amountIn);
        require(transferred, "Token transfer failed");  // Add explicit check for transfer success

        // Verify the tokens were actually received
        uint256 afterBalance = IERC20(token).balanceOf(address(this));
        require(afterBalance >= beforeBalance + amountIn, "Token transfer amount mismatch");

        // Approve PancakeSwap router to spend tokens
        bool approved = IERC20(token).approve(address(pancakeRouter), amountIn);
        require(approved, "Token approval failed");  // Add explicit check for approval success

        // Define swap path: Token -> WBNB
        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = pancakeRouter.WBNB();

        // Perform swap
        uint[] memory amounts = pancakeRouter.swapExactTokensForETH(
            amountIn,
            amountOutMin,
            path,
            address(this),
            deadline
        );

        uint bnbReceived = amounts[1];
        uint fee = (bnbReceived * feeBasisPoints) / BASIS_POINTS;
        uint amountToUser = bnbReceived - fee;

        // Send $BNB to user after fee deduction
        (bool sentToUser, ) = msg.sender.call{value: amountToUser}("");
        require(sentToUser, "BNB transfer to user failed");

        // Send fee to owner
        (bool sentToOwner, ) = owner().call{value: fee}("");
        require(sentToOwner, "Fee transfer failed");

        emit SwappedTokenToBNB(msg.sender, token, amountIn, amountToUser, fee);
    }

    // Allow contract to receive $BNB from PancakeSwap
    receive() external payable {}

    // Withdraw stuck $BNB (emergency owner function)
    function withdrawBNB() external onlyOwner {
        uint balance = address(this).balance;
        require(balance > 0, "No BNB to withdraw");
        (bool sent, ) = owner().call{value: balance}("");
        require(sent, "Withdrawal failed");
    }

    // Withdraw stuck tokens (emergency owner function)
    function withdrawToken(address tokenAddress) external onlyOwner {
        require(tokenAddress != address(0), "Invalid token address");
        uint balance = IERC20(tokenAddress).balanceOf(address(this));
        require(balance > 0, "No tokens to withdraw");
        IERC20(tokenAddress).transfer(owner(), balance);
    }
}