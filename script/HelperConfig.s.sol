// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {CoffeNFT} from "../src/CoffeNFT.sol";
import {Script} from "../lib/forge-std/src/Script.sol";
import {VRFCoordinatorV2_5Mock} from "../test/mock/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mock/LinkToken.sol";

contract HelperConfig is Script {
    CoffeNFT public coffeNFT;
    NetworkConfig public activeNetworkConfig;
    VRFCoordinatorV2_5Mock public vrfCoordinatorV2_5Mock;
    uint96 BASE_FEE = 0.000025 ether;
    uint96 GAS_PRICE_LINK = 1e9;
    int256 WEI_PER_UNIT_LINK = 0.0065 * 1e18;
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
            vrfCoordinator: 0xD7f86b4b8Cae7D942340FF628F82735b7a20893a,
            gasLane: 0xc6bf2e7b88e5cfbb4946ff23af846494ae1f3c65270b79ee7876c9aa99d3d45f,
            subId: 0, // if left free, the script will create one
            callbackGasLimit: 800000,
            mintPrice: 0.1 ether,
            totalSupply: 1000000000000000000000,
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
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subId: 0,
            callbackGasLimit: 2500000,
            mintPrice: 0.1 ether,
            totalSupply: 1000000000000000000000,
            reservedSupply: 150000000000000000000,
            maxMintAmount: 5,
            tokenUri: "ipfs://bafybeih73omsfk6rzjp4hsviaxa2ucpchnnnxpb2bzvgf4dakwbod2rll4",
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
        return sepoliaNetworkConfig;
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        vm.startBroadcast();
        linkToken = new LinkToken();
        vrfCoordinatorV2_5Mock = new VRFCoordinatorV2_5Mock(
            BASE_FEE,
            GAS_PRICE_LINK,
            WEI_PER_UNIT_LINK
        );
        vm.stopBroadcast();
        NetworkConfig memory anvilNetworkConfig = NetworkConfig({
            vrfCoordinator: address(vrfCoordinatorV2_5Mock),
            gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
            subId: 0,
            callbackGasLimit: 2000000, // is set this high so the tests dont fail due to outOfGas error (only for Anvil)
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
