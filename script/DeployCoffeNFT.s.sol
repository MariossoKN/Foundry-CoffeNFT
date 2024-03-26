// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {CoffeNFT} from "../src/CoffeNFT.sol";
import {Script} from "../lib/forge-std/src/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
// import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

contract DeployCoffeNFT is Script {
    CoffeNFT public coffeNft;
    HelperConfig public helperConfig;

    function run() external {
        // get data from HelperConfig for the constructor parameters
        helperConfig = new HelperConfig();
        (
            address vrfCoordinator,
            bytes32 gasLane,
            uint64 subId,
            uint32 callbackGasLimit,
            uint256 mintPrice,
            uint256 totalSupply,
            uint256 reservedSupply,
            uint256 maxMintAmount,
            string memory tokenUri,
            address link,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        // deploying the CoffeNFT contract with the data from HelperConfig
        vm.startBroadcast(deployerKey);
        coffeNft = new CoffeNFT(
            vrfCoordinator,
            gasLane,
            subId,
            callbackGasLimit,
            mintPrice,
            totalSupply,
            reservedSupply,
            maxMintAmount,
            tokenUri
        );
        vm.stopBroadcast();
    }
}
