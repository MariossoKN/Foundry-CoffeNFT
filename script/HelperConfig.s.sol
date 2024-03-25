// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {CoffeNFT} from "../src/CoffeNFT.sol";
import {Script} from "../lib/forge-std/src/Script.sol";
import {VRFCoordinatorV2Mock} from "../test/mock/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mock/LinkToken.sol";

contract HelperConfig is Script {
    CoffeNFT public coffeNFT;
    NetworkConfig public activeNetworkConfig;

    struct NetworkConfig {
        address vrfCoordinator;
        address link;
    }

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else if (block.chainid == 1) {
            activeNetworkConfig = getMainNetEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        NetworkConfig memory sepoliaNetworkConfig = NetworkConfig({
            vrfCoordinator: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625,
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789
        });
        return sepoliaNetworkConfig;
    }

    function getMainNetEthConfig() public pure returns (NetworkConfig memory) {
        NetworkConfig memory mainNetNetworkConfig = NetworkConfig({
            vrfCoordinator: 0x271682DEB8C4E0901D1a1550aD2e64D568E69909,
            link: 0x514910771AF9Ca656af840dff83E8264EcF986CA
        });
        return mainNetNetworkConfig;
    }

    function getOrCreateAnvilEthConfig() public pure returns (NetworkConfig memory) {}
}
