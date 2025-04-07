// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Importing IERC20 from OpenZeppelin
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Importing IWBNB interface manually (specific to WBNB, not in standard libraries)
interface IWBNB is IERC20 {
    function deposit() external payable;
    function withdraw(uint256 wad) external;
}

// Importing PancakeSwap V3 Router interface from official library
import "@pancakeswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

contract VarMetaSwapper {
    address public owner;
    address public constant WBNB = 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd; // WBNB address on BSC testnet
    address public PANCAKE_V3_ROUTER; // PancakeSwap V3 Router on BSC testnet
    uint24 public constant FEE_TIER = 3000; // 0.3% fee tier (common for V3 pools)

    uint256 public platformFeeBasisPoints; // Fee in basis points (e.g., 100 = 1%)

    ISwapRouter public pancakeRouter;

    event SwapExecuted(address indexed user, uint256 amountIn, uint256 amountOut, bool isBNBToToken, address tokenAddress);
    event FeeCollected(address indexed user, uint256 feeAmount, address tokenAddress);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(address _pancakeRouter, uint256 _platformFeeBasisPoints) {
        require(_pancakeRouter != address(0), "Invalid router address");
        owner = msg.sender;
        platformFeeBasisPoints = _platformFeeBasisPoints; // e.g., 100 for 1%
        pancakeRouter = ISwapRouter(_pancakeRouter);
        PANCAKE_V3_ROUTER = _pancakeRouter;
    }

    // Function to swap BNB to any token (collect BNB fee before swap)
    function swapBNBToToken(address tokenOut, uint256 amountOutMinimum, uint256 deadline) external payable {
        require(msg.value > 0, "Insufficient BNB sent");
        // require(tokenOut != address(0) && tokenOut != WBNB, "Invalid token address");
        require(block.timestamp <= deadline, "Transaction deadline exceeded");

        // Calculate and collect BNB fee before swap
        uint256 fee = calculateFee(msg.value);
        require(msg.value > fee, "Insufficient BNB for fee");
        uint256 amountInAfterFee = msg.value - fee;

        // Transfer BNB fee to owner
        (bool sent, ) = owner.call{value: fee}("");
        require(sent, "Failed to transfer BNB fee to owner");
        emit FeeCollected(msg.sender, fee, address(0));

        // Prepare swap parameters
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: WBNB, // WBNB for BNB
            tokenOut: tokenOut, // User-specified token (token A)
            fee: FEE_TIER, // Fee tier for the pool
            recipient: msg.sender, // Recipient of tokens
            deadline: deadline, // Transaction deadline
            amountIn: amountInAfterFee, // Amount of BNB to swap
            amountOutMinimum: amountOutMinimum, // Minimum tokens to receive
            sqrtPriceLimitX96: 0 // No price limit
        });

        // Execute swap
        uint256 amountOut = pancakeRouter.exactInputSingle{value: amountInAfterFee}(params);

        emit SwapExecuted(msg.sender, amountInAfterFee, amountOut, true, tokenOut);
    }

    // Function to swap any token to BNB (collect BNB fee after swap)
    function swapTokenToBNB(address tokenIn, uint256 amountIn, uint256 amountOutMinimum, uint256 deadline) external {
        // require(tokenIn != address(0) && tokenIn != WBNB, "Invalid token address");
        require(amountIn > 0, "Insufficient token amount");
        require(block.timestamp <= deadline, "Transaction deadline exceeded");

        // Transfer tokens from user to this contract
        require(IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn), "Token transfer failed");

        // Approve router to spend tokens
        require(IERC20(tokenIn).approve(PANCAKE_V3_ROUTER, amountIn), "Token approval failed");

        // Prepare swap parameters
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: tokenIn, // User-specified token (token A)
            tokenOut: WBNB, // WBNB for BNB
            fee: FEE_TIER, // Fee tier for the pool
            recipient: address(this), // Contract receives WBNB temporarily
            deadline: deadline, // Transaction deadline
            amountIn: amountIn, // Amount of tokens to swap
            amountOutMinimum: amountOutMinimum, // Minimum BNB to receive
            sqrtPriceLimitX96: 0 // No price limit
        });

        // Execute swap (WBNB will be sent to this contract)
        uint256 amountOut = pancakeRouter.exactInputSingle(params);

        // Unwrap WBNB to native BNB
        IWBNB(WBNB).withdraw(amountOut);

        // Calculate and collect BNB fee after swap
        uint256 fee = calculateFee(amountOut);
        uint256 amountOutForUser = amountOut - fee;

        // Transfer BNB to owner as fee
        (bool sent, ) = owner.call{value: fee}("");
        require(sent, "Failed to transfer BNB fee to owner");
        emit FeeCollected(msg.sender, fee, tokenIn);

        // Transfer remaining BNB to user
        (sent, ) = msg.sender.call{value: amountOutForUser}("");
        require(sent, "Failed to transfer remaining BNB to user");

        emit SwapExecuted(msg.sender, amountIn, amountOutForUser, false, tokenIn);
    }

    // Calculate BNB fee based on amount
    function calculateFee(uint256 amount) private view returns (uint256) {
        return (amount * platformFeeBasisPoints) / 10000; // Convert basis points to percentage
    }

    // Function to update fee settings (only owner)
    function updateFeeSettings(uint256 newFeeBasisPoints) external onlyOwner {
        require(newFeeBasisPoints <= 10000, "Fee too high"); // Max 100% (10000 basis points)
        platformFeeBasisPoints = newFeeBasisPoints;
    }

    // Function to withdraw any accidentally sent tokens or BNB (only owner)
    function withdraw(address token, uint256 amount) external onlyOwner {
        if (token == address(0)) {
            (bool sent, ) = msg.sender.call{value: amount}("");
            require(sent, "Failed to withdraw BNB");
        } else {
            require(IERC20(token).transfer(msg.sender, amount), "Failed to withdraw tokens");
        }
    }

    // Fallback function to receive BNB
    receive() external payable {}
}