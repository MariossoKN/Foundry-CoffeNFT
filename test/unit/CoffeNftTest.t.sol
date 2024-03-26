// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {CoffeNFT} from "../../src/CoffeNFT.sol";
import {DeployCoffeNFT} from "../../script/DeployCoffeNFT.s.sol";
import {Vm} from "../../lib/forge-std/src/Vm.sol";
import {Test, console} from "../../lib/forge-std/src/Test.sol";
import {VRFCoordinatorV2Mock} from "../../test/mock/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../../test/mock/LinkToken.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract CoffeNftTest is Test {
    CoffeNFT public coffeNft;
    VRFCoordinatorV2Mock public vrfCoordinatorV2Mock;
    LinkToken public linkToken;
    DeployCoffeNFT public deployCoffeNft;
    HelperConfig public helperConfig;

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

    address USER = makeAddr("user");
    address USER2 = makeAddr("user2");

    uint256 constant STARTING_BALANCE = 20 ether;
    uint256 enough_mint_price;
    uint256 not_enough_mint_price;

    function setUp() external {
        deployCoffeNft = new DeployCoffeNFT();
        (coffeNft, helperConfig) = deployCoffeNft.run();
        (
            vrfCoordinator,
            gasLane,
            subId,
            callbackGasLimit,
            mintPrice,
            totalSupply,
            reservedSupply,
            maxMintAmount,
            tokenUri,
            link,
            deployerKey
        ) = helperConfig.activeNetworkConfig();
        enough_mint_price = mintPrice;
        not_enough_mint_price = mintPrice - 1;
        vm.deal(USER, STARTING_BALANCE);
    }

    function testConstructorParameters() public {
        assertEq(address(coffeNft.getVrfCoordinatorAddress()), vrfCoordinator);
        assertEq(coffeNft.getGasLane(), gasLane);
        assertEq(coffeNft.getSubId(), subId);
        assertEq(coffeNft.getCallbackGasLimit(), callbackGasLimit);
        assertEq(coffeNft.getMintPrice(), mintPrice);
        assertEq(coffeNft.getTotalSupply(), totalSupply);
        assertEq(coffeNft.getReservedSupply(), reservedSupply);
        assertEq(coffeNft.getMaxMintAmount(), maxMintAmount);
        assertEq(coffeNft.getTokenUris(), tokenUri);
    }
}
