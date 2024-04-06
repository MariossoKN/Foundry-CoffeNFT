// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {CoffeNFT} from "../src/CoffeNFT.sol";
import {Script} from "../lib/forge-std/src/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "../test/mock/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mock/LinkToken.sol";
import {DevOpsTools} from "../lib/foundry-devops/src/DevOpsTools.sol";

// import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
// import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

contract DeployCoffeNFT is Script {
    CoffeNFT public coffeNft;
    HelperConfig public helperConfig;

    uint96 constant AMOUNT_TO_FUND = 5 ether;

    function run() external returns (CoffeNFT, HelperConfig) {
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

        if (subId == 0) {
            vm.startBroadcast(deployerKey);
            (subId) = VRFCoordinatorV2Mock(vrfCoordinator).createSubscription();
            vm.stopBroadcast();

            if (block.chainid == 31337) {
                vm.startBroadcast(deployerKey);
                VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(subId, AMOUNT_TO_FUND);
                vm.stopBroadcast();
            } else {
                vm.startBroadcast(deployerKey);
                LinkToken(link).transferAndCall(address(vrfCoordinator), AMOUNT_TO_FUND, abi.encode(subId));
                vm.stopBroadcast();
            }
        }

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

        // address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("CoffeNFT", block.chainid);

        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(subId, address(coffeNft));
        vm.stopBroadcast();
        return (coffeNft, helperConfig);
    }
}
