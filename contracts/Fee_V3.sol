// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@pancakeswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import '@pancakeswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import '@pancakeswap/v3-core/contracts/interfaces/IPancakeV3Factory.sol';

interface IWBNB {
    function deposit() external payable;
    function withdraw(uint wad) external;
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IBep20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}
interface IBEP20Extended is IBep20 {
    function decimals() external view returns (uint8);
}


contract VarMetaSwapper {
    address public owner;
    address public constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c; // WBNB address on BSC mainnet
    address public constant USDT = 0x55d398326f99059fF775485246999027B3197955; // USDT address on BSC mainnet
    address public constant USDC = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d; // USDC address on BSC mainnet
    


    address public PANCAKE_V3_ROUTER; // PancakeSwap V3 Router on BSC testnet
    address public PAN_V3_FACTORY; // PancakeSwap V3 Factory on BSC testnet
    IWBNB public wbnb_router;

    uint256 public platformFeeBasisPoints; // Fee in basis points (e.g., 100 = 1%)

    ISwapRouter public pancakeRouter;
    IPancakeV3Factory public pancakeFactory;

    // Constants to reduce gas usage
    uint24 private constant FEE_TIER_500 = 500;
    // uint24 private constant FEE_TIER_2500 = 2500;
    // uint24 private constant FEE_TIER_3000 = 3000;
    // uint24 private constant FEE_TIER_5000 = 5000;
    // uint24 private constant FEE_TIER_10000 = 10000;

    event SwapExecuted(address indexed user, uint256 amountIn, uint256 amountOut, bool isBNBToToken, address tokenAddress);
    event FeeCollected(address indexed user, uint256 feeAmount, address tokenAddress);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(address _pancakeRouter, address _pancakeFactory, uint256 _platformFeeBasisPoints) {
        require(_pancakeRouter != address(0), "Invalid router address");
        owner = msg.sender;
        platformFeeBasisPoints = _platformFeeBasisPoints; // e.g., 100 for 1%
        pancakeRouter = ISwapRouter(_pancakeRouter);
        PANCAKE_V3_ROUTER = _pancakeRouter;
        // hardcode factory address
        PAN_V3_FACTORY = _pancakeFactory;
        pancakeFactory = IPancakeV3Factory(PAN_V3_FACTORY);
        wbnb_router = IWBNB(WBNB);
        
    }

    // Function to swap BNB to any token (collect BNB fee before swap)
    // Because we need user to approve WBNB before swap, then dont need to wrap BNB anymore.
    function swapWBNB2Token(uint256 amountIn, address tokenOut, uint256 amountOutMinimum, uint256 deadline) external payable {
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

    function swapBNB2Token(address tokenOut, uint256 amountOutMinimum, uint256 deadline) external payable {
        require(block.timestamp <= deadline, "IVL_DEADLINE");
        require(tokenOut != address(0), "IVL_ADDR_OUT");
        require(msg.value > 0, "IVL_AMT_IN");
        uint256 amountIn = msg.value;
        // Calculate and collect BNB fee before swap
        uint256 fee = calculateFee(amountIn);
        uint256 amountInAfterFee = amountIn - fee;

        // Transfer BNB fee to owner - failed with STE
        TransferHelper.safeTransferETH(owner, fee);
        // call to WBNB to wrap BNB
        wbnb_router.deposit{value: amountInAfterFee}();
        emit SwapExecuted(msg.sender, amountInAfterFee, 0, true, WBNB);
        // Approve router to spend WBNB
        TransferHelper.safeApprove(WBNB, address(PANCAKE_V3_ROUTER), amountInAfterFee);

        emit FeeCollected(msg.sender, fee, address(0));
            
        uint24 feeTier = getFeeTier(WBNB, tokenOut);
        require(feeTier != 0, "No pool found");
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: WBNB,
            tokenOut: tokenOut,
            fee: feeTier,
            recipient: msg.sender,
            deadline: deadline,
            amountIn: amountInAfterFee,
            amountOutMinimum: amountOutMinimum,
            sqrtPriceLimitX96: 0 // No price limit
        });

        try pancakeRouter.exactInputSingle(params) returns (uint256 amountOut) {
            emit SwapExecuted(msg.sender, amountInAfterFee, amountOut, true, tokenOut);
        } catch Error(string memory reason) {
            revert(reason); // router errors
        } catch {
            revert("Swap failed due to an unknown error");
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
        uint24 feeTier = getFeeTier(tokenIn, WBNB);

        // Prepare swap parameters
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: tokenIn, // User-specified token (token A)
            tokenOut: WBNB, // WBNB for BNB
            fee: feeTier, // Fee tier for the pool
            recipient: address(this), // Contract receives WBNB temporarily
            deadline: deadline, // Transaction deadline
            amountIn: amountIn, // Amount of tokens to swap
            amountOutMinimum: amountOutMinimum, // Minimum BNB to receive
            sqrtPriceLimitX96: 0 // No price limit
        });
        try pancakeRouter.exactInputSingle(params) returns (uint256 amountOut) {
            // unwrap WBNB
            wbnb_router.withdraw(amountOut);
            uint256 fee = calculateFee(amountOut);
            uint256 amountOutForUser = amountOut - fee;
            // Transfer BNB fee to owner - failed with STE
            TransferHelper.safeTransferETH(owner, fee);
            emit FeeCollected(msg.sender, fee, address(0));
            // Transfer BNB to user
            TransferHelper.safeTransferETH(msg.sender, amountOutForUser);
            emit SwapExecuted(msg.sender, amountIn, amountOutForUser, false, tokenIn);
        } catch Error(string memory reason) {
            revert(reason); // router errors
        } catch {
            revert("Swap failed due to an unknown error");
        }
    }

    // swap U2B before buying target token. After this action, contract will have WBNB
    function swapU2BNB(uint8 mode, uint256 amountIn, uint256 amountOutMinimum, uint256 deadline) internal returns (uint256) {
        address tokenIn;
        if (mode == 2) {
            tokenIn = USDC;
        } else if (mode == 4) {
            tokenIn = USDT;
        } else {
            revert("Invalid mode");
        }

        uint24 feeTier = getFeeTier(tokenIn, WBNB);
        require(feeTier != 0, "No pool found");
        // Prepare swap parameters
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: tokenIn, // User-specified token (token A)
            tokenOut: WBNB,
            fee: feeTier, // Fee tier for the pool
            recipient: address(this), // Contract receives WBNB temporarily
            deadline: deadline, // Transaction deadline
            amountIn: amountIn, // Amount of tokens to swap
            amountOutMinimum: amountOutMinimum, // Minimum BNB to receive
            sqrtPriceLimitX96: 0 // No price limit
        });
        try pancakeRouter.exactInputSingle(params) returns (uint256 amountOut) {
            // unwrap WBNB
            wbnb_router.withdraw(amountOut);
            return amountOut;
        } catch Error(string memory reason) {
            revert(reason); // router errors
        } catch {
            revert("Swap failed token to WBNB");
        }
    }

    // swap WBNB to USDC/USDT after buying target token. After this action, contract will have USDC/USDT
    function swapBNB2U(uint8 mode, uint256 amountIn, uint256 amountOutMinimum, uint256 deadline) internal returns (uint256) {
        address tokenOut;
        if (mode == 3) {
            tokenOut = USDC;
        } else if (mode == 5) {
            tokenOut = USDT;
        } else {
            revert("Invalid mode");
        }
        // Approve router to spend WBNB
        TransferHelper.safeApprove(WBNB, address(PANCAKE_V3_ROUTER), amountIn);
        // get feeTier for pairs
        uint24 feeTier = getFeeTier(WBNB, tokenOut);
        require(feeTier != 0, "No pool found");
        // Prepare swap parameters
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: WBNB, // WBNB for swapping
            tokenOut: tokenOut, // User-specified token (token A)
            fee: feeTier, // Fee tier for the pool
            recipient: address(this), // Recipient of tokens
            deadline: deadline, // Transaction deadline
            amountIn: amountIn, // Amount of BNB to swap
            amountOutMinimum: amountOutMinimum, // Minimum tokens to receive
            sqrtPriceLimitX96: 0 // No price limit
        });

        // Execute swap -> send output token to user and revert if error
        try pancakeRouter.exactInputSingle(params) returns (uint256 amountOut) {
            bool sentTarget = IERC20(tokenOut).transfer(msg.sender, amountOut);
            require(sentTarget, "TRANS_AFTER_SWAP_FAILED");
            emit SwapExecuted(msg.sender, amountIn, amountOut, false, tokenOut);
            return amountOut;
        } catch Error(string memory reason) {
            revert(reason); // router errors
        } catch {
            revert("Swap failed due to an unknown error"); // unknown problems
        }
    }

    // Function to swap any token to BNB (collect BNB fee after swap)
    function swapToken2WBNB(address tokenIn, uint256 amountIn, uint256 amountOutMinimum, uint256 deadline) external {
        // require(tokenIn != address(0) && tokenIn != WBNB, "Invalid token address");
        require(amountIn > 0, "Insufficient token amount");
        require(block.timestamp <= deadline, "Transaction deadline exceeded");

        // Transfer tokens from user to this contract
        require(IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn), "Token transfer failed");

        // Approve router to spend tokens
        require(IERC20(tokenIn).approve(PANCAKE_V3_ROUTER, amountIn), "Token approval failed");
        uint24 feeTier = getFeeTier(tokenIn, WBNB);

        // Prepare swap parameters
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: tokenIn, // User-specified token (token A)
            tokenOut: WBNB, // WBNB for BNB
            fee: feeTier, // Fee tier for the pool
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
        require(sent, "Failed");
        emit SwapExecuted(msg.sender, amountIn, amountOutForUser, false, tokenIn);
    }
    /*
        @dev Mode List:
        - 2: USDC to Token
        - 3: Token to USDC
        - 4: USDT to Token
        - 5: Token to USDT
        - 6: Token to Token
        @dev we added these modes to make it easier for futher fee calculating
    */

    // Swap any token to any token (collect fee before or after swap)
    function swapTokenToToken(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMinimum,
        uint256 deadline,
        uint8 mode
    ) external {
        require(tokenIn != address(0) && tokenOut != address(0), "Invalid token address");
        require(amountIn > 0, "Insufficient token amount");
        require(block.timestamp <= deadline, "Transaction deadline exceeded");

        // Transfer tokens from user to this contract
        require(IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn), "Token transfer failed");

        // Approve router to spend tokens
        require(IERC20(tokenIn).approve(PANCAKE_V3_ROUTER, amountIn), "Token approval failed");
        ISwapRouter.ExactInputSingleParams memory params;
        

        // check mode
        if (mode == 2 || mode == 4) {
            uint256 fee = calculateFee(amountIn);
            uint256 amountInAfterFee = amountIn - fee;
            // Transfer fee to owner
            bool sent = IERC20(tokenIn).transfer(owner, fee);
            require(sent, "Fee transfer failed");
            emit FeeCollected(msg.sender, fee, tokenIn);
           // swap USDC/USDT to WBNB
            uint256 amountOfWBNB = swapU2BNB(mode, amountInAfterFee, amountOutMinimum, deadline);
            wbnb_router.deposit{value: amountOfWBNB}();
            TransferHelper.safeApprove(WBNB, address(PANCAKE_V3_ROUTER), amountOfWBNB);
            // get fee for pairs
            uint24 feeTier = getFeeTier(WBNB, tokenOut);
            require(feeTier != 0, "No pool found");
            // Prepare swap parameters
            params = ISwapRouter.ExactInputSingleParams({
                tokenIn: WBNB, // User-specified token (token A)
                tokenOut: tokenOut, // User-specified token (token B)
                fee: feeTier, // Fee tier for the pool
                recipient: msg.sender,
                deadline: deadline, // Transaction deadline
                amountIn: amountOfWBNB, // Amount of tokens to swap
                amountOutMinimum: amountOutMinimum, // Minimum tokens to receive
                sqrtPriceLimitX96: 0 // No price limit
            });
            // Execute swap (tokenOut will be sent to user)
            try pancakeRouter.exactInputSingle(params) returns (uint256 amountOut) {
                emit SwapExecuted(msg.sender, amountOfWBNB, amountOut, true, tokenOut);
            } catch Error(string memory reason) {
                revert(reason); // router errors
            } catch {
                revert("Swap failed due to an unknown error");
            }
        }

        // selling token to USDC/USDT. First sell to WBWB then swap to USDT/USDC
        if ( mode == 3 || mode == 5) {
            // get fee for pairs
            uint24 feeTier = getFeeTier(tokenIn, WBNB);
            require(feeTier != 0, "No pool found");
            // Prepare swap parameters
            params = ISwapRouter.ExactInputSingleParams({
                tokenIn: tokenIn, // User-specified token (token A)
                tokenOut: WBNB, // User-specified token (token B)
                fee: feeTier, // Fee tier for the pool
                recipient: address(this), // Contract receives WBNB temporarily
                deadline: deadline, // Transaction deadline
                amountIn: amountIn, // Amount of tokens to swap
                amountOutMinimum: amountOutMinimum, // Minimum tokens to receive
                sqrtPriceLimitX96: 0 // No price limit
            });

            // Execute swap (wbnb temp be hold in contract)
            uint256 amountOut = pancakeRouter.exactInputSingle(params);
            emit SwapExecuted(msg.sender, amountIn, amountOut, false, tokenOut);
            // calculate fee after swap
            uint256 fee = calculateFee(amountOut);
            uint256 amountWBNBtoSwapAfterFee = amountOut - fee;
            // Transfer fee to owner
            bool sent = IERC20(WBNB).transfer(owner, fee);
            require(sent, "FTF");
            emit FeeCollected(msg.sender, fee, tokenOut);

            // swap WBNB to USDC/USDT
            swapBNB2U(mode, amountWBNBtoSwapAfterFee, amountOutMinimum, deadline);

        }
        
    }

    // get pool pair and check if balance of tokenA and tokenB is over 100 tokens
    function getFeeTier(address tokenA, address tokenB) public view returns (uint24) {
        uint24[5] memory feeTiers = [FEE_TIER_500, 2500, 3000, 5000, 10000];

        IBEP20Extended tokenA_ = IBEP20Extended(tokenA);
        IBEP20Extended tokenB_ = IBEP20Extended(tokenB);

        uint8 decimalsA = tokenA_.decimals();
        uint8 decimalsB = tokenB_.decimals();

        uint256 thresholdA = 100 * (10 ** decimalsA);
        uint256 thresholdB = 100 * (10 ** decimalsB);

        for (uint256 i = 0; i < 5; ) {
            address pool = pancakeFactory.getPool(tokenA, tokenB, feeTiers[i]);
            if (pool != address(0)) {
                uint256 balA = tokenA_.balanceOf(pool);
                uint256 balB = tokenB_.balanceOf(pool);
                if (balA > thresholdA && balB > thresholdB) {
                    return feeTiers[i];
                }
            }
            unchecked { ++i; }
        }

        return 0;
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

    function refund() internal {
        // Unwrap BNB and send back
        wbnb_router.withdraw(msg.value);
        (bool success, ) = msg.sender.call{value: msg.value}("");
        require(success, "RFF");
    }

    // Fallback function to receive BNB
    receive() external payable {}
}