// Sources flattened with hardhat v2.22.19 https://hardhat.org

// SPDX-License-Identifier: MIT

// File @openzeppelin/contracts/utils/Context.sol@v5.2.0

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

pragma solidity ^0.8.20;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}


// File @openzeppelin/contracts/access/Ownable.sol@v5.2.0

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable.sol)

pragma solidity ^0.8.20;

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * The initial owner is set to the address provided by the deployer. This can
 * later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    /**
     * @dev The caller account is not authorized to perform an operation.
     */
    error OwnableUnauthorizedAccount(address account);

    /**
     * @dev The owner is not a valid owner account. (eg. `address(0)`)
     */
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the address provided by the deployer as the initial owner.
     */
    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}


// File @openzeppelin/contracts/token/ERC20/IERC20.sol@v5.2.0

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.20;

/**
 * @dev Interface of the ERC-20 standard as defined in the ERC.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}


// File contracts/Fee_Mdw.sol

// Original license: SPDX_License_Identifier: MIT
pragma solidity ^0.8.20;


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
        require(_initialFeeBasisPoints <= BASIS_POINTS, "Fee exceeds 100%");

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

        // Transfer tokens from user to contract
        IERC20(token).transferFrom(msg.sender, address(this), amountIn);

        // Approve PancakeSwap router to spend tokens
        IERC20(token).approve(address(pancakeRouter), amountIn);

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
