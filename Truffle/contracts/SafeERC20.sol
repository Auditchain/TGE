pragma solidity ^0.4.24;


import "./interfaces/IERC20.sol";
import "./Token.sol";


/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure.
 * To use this library you can add a `using SafeERC20 for ERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    function safeTransfer(Token token, address to, uint256 value) internal {
        require(token.transfer(to, value));
    }

    function safeTransferFrom(
        Token token,
        address from,
        address to,
        uint256 value
    )
        internal
    {
        require(token.transferFrom(from, to, value));
    }

    function safeApprove(Token token, address spender, uint256 value) internal {
        require(token.approve(spender, value));
    }
}