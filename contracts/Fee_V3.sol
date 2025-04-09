// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@pancakeswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import '@pancakeswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import '@pancakeswap/v3-core/contracts/interfaces/IPancakeV3Factory.sol';

// Importing IWBNB interface manually (specific to WBNB, not in standard libraries)
interface IWBNB is IERC20 {
    function deposit() external payable;
    function withdraw(uint256 wad) external;
}

contract VarMetaSwapper {
    address public owner;
    // Native token will be convert to WBNB before executing swap
    address public constant WBNB = 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd; // WBNB address on BSC testnet
    address public PANCAKE_V3_ROUTER; // PancakeSwap V3 Router on BSC testnet
    address public PAN_V3_FACTORY; // PancakeSwap V3 Factory on BSC testnet
    uint24 public constant FEE_TIER = 10000; // 1% fee tier (common for V3 pools)

    uint256 public platformFeeBasisPoints; // Fee in basis points (e.g., 100 = 1%)

    ISwapRouter public pancakeRouter;
    IPancakeV3Factory public pancakeFactory;

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
        // hardcode factory address
        PAN_V3_FACTORY = 0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865;
        pancakeFactory = IPancakeV3Factory(PAN_V3_FACTORY);
        
    }

    // Function to swap BNB to any token (collect BNB fee before swap)
    // Because we need user to approve WBNB before swap, then dont need to wrap BNB anymore.
    function swapBNB2Token(uint256 amountIn, address tokenOut, uint256 amountOutMinimum, uint256 deadline) external payable {
        require(block.timestamp <= deadline, "Transaction deadline exceeded");
        require(tokenOut != address(0), "Invalid token out address");
        require(amountIn > 0, "Insufficient token amount");
        TransferHelper.safeTransferFrom(WBNB, msg.sender, address(this), amountIn);
        // Approve router to spend WBNB
        TransferHelper.safeApprove(WBNB, address(PANCAKE_V3_ROUTER), amountIn);

        // Calculate and collect BNB fee before swap
        uint256 fee = calculateFee(amountIn);
        uint256 amountInAfterFee = amountIn - fee;

        // Transfer BNB fee to owner
        bool success = IERC20(WBNB).transfer(owner, fee);
        require(success, "Fee transfer failed");
        emit FeeCollected(msg.sender, fee, address(0));
    
        // get feeTier for pairs
        uint24 feeTier = getFeeTier(WBNB, tokenOut);
        // Prepare swap parameters
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: WBNB, // WBNB for swapping
            tokenOut: tokenOut, // User-specified token (token A)
            fee: feeTier, // Fee tier for the pool
            recipient: msg.sender, // Recipient of tokens
            deadline: deadline, // Transaction deadline
            amountIn: amountInAfterFee, // Amount of BNB to swap
            amountOutMinimum: amountOutMinimum, // Minimum tokens to receive
            sqrtPriceLimitX96: 0 // No price limit
        });

        // Execute swap and revert if error
        try pancakeRouter.exactInputSingle(params) returns (uint256 amountOut) {
            emit SwapExecuted(msg.sender, amountInAfterFee, amountOut, true, tokenOut);
        } catch Error(string memory reason) {
            revert(reason); // router errors
        } catch {
            revert("Swap failed due to an unknown error"); // unknown problems
        }
    }

    // Function to swap any token to BNB (collect BNB fee after swap)
    function swapToken2BNB(address tokenIn, uint256 amountIn, uint256 amountOutMinimum, uint256 deadline) external {
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

        // Calculate and collect BNB fee after swap
        uint256 fee = calculateFee(amountOut);
        uint256 amountOutForUser = amountOut - fee;

        // Transfer BNB fee to owner
        bool success = IERC20(WBNB).transfer(owner, fee);
        require(success, "Fee transfer failed");
        emit FeeCollected(msg.sender, fee, address(0));

        // Transfer swapped BNB for user
        bool sent = IERC20(WBNB).transfer(msg.sender, amountOutForUser);
        require(sent, "lol");
        emit SwapExecuted(msg.sender, amountIn, amountOutForUser, false, tokenIn);
    }
    // Wrap BNB to WBNB (no fee)
    function wrapBNB() external payable{
        IWBNB(WBNB).deposit{value: msg.value}();
        emit SwapExecuted(msg.sender, msg.value, 0, true, WBNB);
    }

    function swapTokenToToken(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMinimum,
        uint256 deadline
    ) external {
        require(tokenIn != address(0) && tokenOut != address(0), "Invalid token address");
        require(amountIn > 0, "Insufficient token amount");
        require(block.timestamp <= deadline, "Transaction deadline exceeded");

        // Transfer tokens from user to this contract
        require(IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn), "Token transfer failed");

        // Approve router to spend tokens
        require(IERC20(tokenIn).approve(PANCAKE_V3_ROUTER, amountIn), "Token approval failed");
        ISwapRouter.ExactInputSingleParams memory params;
        // If user swap WBNB to token, collect fee before swap
        if (tokenIn == WBNB) {
            uint256 fee = calculateFee(amountIn);
            uint256 amountInAfterFee = amountIn - fee;

            // Transfer BNB fee to owner
            (bool sent, ) = owner.call{value: fee}("");
            require(sent, "Failed to transfer amount fee to owner");
            emit FeeCollected(msg.sender, fee, tokenIn);

            // Update amountIn for swap
            amountIn = amountInAfterFee;

            // get fee for pairs
            uint24 feeTier = getFeeTier(tokenIn, tokenOut);
            // Prepare swap parameters
            params = ISwapRouter.ExactInputSingleParams({
                tokenIn: tokenIn, // User-specified token (token A)
                tokenOut: tokenOut, // User-specified token (token B)
                fee: feeTier, // Fee tier for the pool
                recipient: msg.sender, // Recipient of tokens
                deadline: deadline, // Transaction deadline
                amountIn: amountIn, // Amount of tokens to swap
                amountOutMinimum: amountOutMinimum, // Minimum tokens to receive
                sqrtPriceLimitX96: 0 // No price limit
            });

            // Execute swap (tokenOut will be sent to user)
            uint256 amountOut = pancakeRouter.exactInputSingle(params);

            emit SwapExecuted(msg.sender, amountIn, amountOut, false, tokenOut);
        } else {
            // Prepare swap parameters
            params = ISwapRouter.ExactInputSingleParams({
                tokenIn: tokenIn, // User-specified token (token A)
                tokenOut: tokenOut, // User-specified token (token B)
                fee: FEE_TIER, // Fee tier for the pool
                recipient: msg.sender, // Recipient of tokens
                deadline: deadline, // Transaction deadline
                amountIn: amountIn, // Amount of tokens to swap
                amountOutMinimum: amountOutMinimum, // Minimum tokens to receive
                sqrtPriceLimitX96: 0 // No price limit
            });
        }
    }

    // get pool pair
    function getFeeTier(address tokenA, address tokenB) public view returns (uint24) {
        uint24 FEE_TIER_500 = 500;
        uint24 FEE_TIER_3000 = 3000;
        uint24 FEE_TIER_2500 = 2500;
        uint24 FEE_TIER_10000 = 10000;

        address pool = pancakeFactory.getPool(tokenA, tokenB, FEE_TIER_500);
        if (pool != address(0)) {
            return FEE_TIER_500;
        } else {
            pool = pancakeFactory.getPool(tokenA, tokenB, FEE_TIER_2500);
            if (pool != address(0)) {
                return FEE_TIER_2500;
            } else {
                pool = pancakeFactory.getPool(tokenA, tokenB, FEE_TIER_3000);
                if (pool != address(0)) {
                    return FEE_TIER_3000;
                } else {
                    pool = pancakeFactory.getPool(tokenA, tokenB, FEE_TIER_10000);
                    if (pool != address(0)) {
                        return FEE_TIER_10000;
                    }
                }
            }
        }
        return 0; // No pool found
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