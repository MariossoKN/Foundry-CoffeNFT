// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {CoffeNFT} from "../../src/CoffeNFT.sol";
import {DeployCoffeNFT} from "../../script/DeployCoffeNFT.s.sol";
import {Vm} from "../../lib/forge-std/src/Vm.sol";
import {Test, console} from "../../lib/forge-std/src/Test.sol";
import {VRFCoordinatorV2Mock} from "../../test/mock/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../../test/mock/LinkToken.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";

contract CoffeNftTest is StdInvariant, Test {
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
        // reading the config data twice to prevent stack too deep error
        (vrfCoordinator, gasLane, subId, callbackGasLimit, mintPrice, totalSupply, reservedSupply,,,,) =
            helperConfig.activeNetworkConfig();
        (,,,,,,, maxMintAmount, tokenUri, link, deployerKey) = helperConfig.activeNetworkConfig();
        enough_mint_price = mintPrice;
        not_enough_mint_price = mintPrice - 1;
        vm.deal(USER, STARTING_BALANCE);
        vm.deal(USER2, STARTING_BALANCE);
    }

    // modifiers TEST //
    modifier setMintStatusToOpen() {
        address owner = coffeNft.owner();
        vm.prank(owner);
        coffeNft.setMintStatusOpen();
        _;
    }

    // constructor TEST //
    function testConstructorParameters() public view {
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

    // requestNft TEST //
    function testMintAmountCantBeZero() public setMintStatusToOpen {
        vm.prank(USER);
        vm.expectRevert(CoffeNFT.CoffeNft__WrongMintAmount.selector);
        coffeNft.requestNft{value: enough_mint_price}(0);
    }

    function testRequest() public setMintStatusToOpen {
        assertEq(coffeNft.balanceOf(USER), 0);
        vm.prank(USER);
        coffeNft.requestNft{value: enough_mint_price}(1);
        // assertEq(coffeNft.balanceOf(USER), 1);
        // assertEq(coffeNft.getMintAmount(USER), 1);
    }

    // function testFuzzMintAmountCantBeMoreThanMaxMintAmount(uint32 _amount) public {
    //     uint256 maxUint32 = type(uint32).max;
    //     uint256 amount = bound(_amount, 0, 5);
    //     vm.prank(USER);
    //     vm.expectRevert(CoffeNFT.CoffeNft__WrongMintAmount.selector);
    //     coffeNft.requestNft(uint32(amount));
    // }
}
