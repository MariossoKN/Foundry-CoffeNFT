// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {CoffeNFT} from "../src/CoffeNFT.sol";
import {Script} from "../lib/forge-std/src/Script.sol";
import {VRFCoordinatorV2Mock} from "../test/mock/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mock/LinkToken.sol";

contract HelperConfig is Script {
    CoffeNFT public coffeNFT;
    NetworkConfig public activeNetworkConfig;
    VRFCoordinatorV2Mock public vrfCoordinatorV2Mock;
    uint96 BASE_FEE = 0.25 ether;
    uint96 GAS_PRICE_LINK = 1e9;
    LinkToken public linkToken;
    uint256 public constant DEFAULT_ANVIL_PRIVATE_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    struct NetworkConfig {
        address vrfCoordinator;
        bytes32 gasLane;
        uint64 subId;
        uint32 callbackGasLimit;
        uint256 mintPrice;
        uint256 totalSupply;
        uint256 reservedSupply;
        uint256 maxMintAmount;
        string tokenUri;
        address link;
        uint256 deployerKey;
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

    function getMainNetEthConfig() public view returns (NetworkConfig memory) {
        NetworkConfig memory mainNetNetworkConfig = NetworkConfig({
            vrfCoordinator: 0x271682DEB8C4E0901D1a1550aD2e64D568E69909,
            gasLane: 0x9fe0eebf5e446e3c998ec9bb19951541aee00bb90ea201ae456421a2ded86805,
            subId: 0, // if left free, the script will create one
            callbackGasLimit: 800000,
            mintPrice: 0.1 ether,
            totalSupply: 10000000000000000000000,
            reservedSupply: 150000000000000000000,
            maxMintAmount: 5,
            tokenUri: "ipfs://bafybeih73omsfk6rzjp4hsviaxa2ucpchnnnxpb2bzvgf4dakwbod2rll4",
            link: 0x514910771AF9Ca656af840dff83E8264EcF986CA,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
        return mainNetNetworkConfig;
    }

    function getSepoliaEthConfig() public view returns (NetworkConfig memory) {
        NetworkConfig memory sepoliaNetworkConfig = NetworkConfig({
            vrfCoordinator: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625,
            gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
            subId: 0,
            callbackGasLimit: 800000,
            mintPrice: 0.1 ether,
            totalSupply: 10000000000000000000000,
            reservedSupply: 150000000000000000000,
            maxMintAmount: 5,
            tokenUri: "ipfs://bafybeih73omsfk6rzjp4hsviaxa2ucpchnnnxpb2bzvgf4dakwbod2rll4",
            link: 0x514910771AF9Ca656af840dff83E8264EcF986CA,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
        return sepoliaNetworkConfig;
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        vm.startBroadcast();
        linkToken = new LinkToken();
        vrfCoordinatorV2Mock = new VRFCoordinatorV2Mock(BASE_FEE, GAS_PRICE_LINK);
        vm.stopBroadcast();
        NetworkConfig memory anvilNetworkConfig = NetworkConfig({
            vrfCoordinator: address(vrfCoordinatorV2Mock),
            gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
            subId: 0,
            callbackGasLimit: 800000,
            mintPrice: 0.1 ether,
            totalSupply: 100000000000000000000, // 100
            reservedSupply: 15000000000000000000, // 15
            maxMintAmount: 5,
            tokenUri: "ipfs://bafybeih73omsfk6rzjp4hsviaxa2ucpchnnnxpb2bzvgf4dakwbod2rll4",
            link: address(linkToken),
            deployerKey: DEFAULT_ANVIL_PRIVATE_KEY
        });
        return anvilNetworkConfig;
    }
}
