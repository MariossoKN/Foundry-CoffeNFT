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
        // assertEq(coffeNft.getSubId(), subId);
        assertEq(coffeNft.getCallbackGasLimit(), callbackGasLimit);
        assertEq(coffeNft.getMintPrice(), mintPrice);
        assertEq(coffeNft.getTotalSupply(), totalSupply);
        assertEq(coffeNft.getReservedSupply(), reservedSupply);
        assertEq(coffeNft.getMaxMintAmount(), maxMintAmount);
        assertEq(coffeNft.getTokenUris(), tokenUri);
    }

    function testMintStateStartsClosed() public view {
        assertEq(coffeNft.getMintStatus(), false);
    }

    // requestNft TEST //
    function testMintAmountCantBeZero() public {
        vm.prank(USER);
        vm.expectRevert(CoffeNFT.CoffeNft__WrongMintAmount.selector);
        coffeNft.requestNft{value: enough_mint_price}(0);
    }

    function testFuzzMintAmountCantBeMoreThanMaxMintAmount(uint32 _amount) public setMintStatusToOpen {
        uint256 maxUint32 = type(uint32).max;
        uint256 amount = bound(_amount, maxMintAmount + 1, maxUint32);
        vm.prank(USER);
        vm.expectRevert(CoffeNFT.CoffeNft__WrongMintAmount.selector);
        coffeNft.requestNft(uint32(amount));
    }

    function testRevertsIfMintNotOpen() public {
        vm.prank(USER);
        vm.expectRevert(CoffeNFT.CoffeNft__MintNotActive.selector);
        coffeNft.requestNft{value: enough_mint_price}(1);
    }

    function testRevertsIfNotEnoughEthSentWithOneRequest() public setMintStatusToOpen {
        vm.prank(USER);
        vm.expectRevert(CoffeNFT.CoffeNft__NotEnoughEthSent.selector);
        coffeNft.requestNft{value: not_enough_mint_price}(1);
    }

    function testRevertsIfNotEnoughEthSentWithMultpleRequests() public setMintStatusToOpen {
        uint32 amountMinted = 4;
        vm.prank(USER);
        vm.expectRevert(CoffeNFT.CoffeNft__NotEnoughEthSent.selector);
        coffeNft.requestNft{value: not_enough_mint_price * amountMinted}(amountMinted);
    }

    function testFuzzRevertsIfNotEnoughEthSent(uint256 _amount) public setMintStatusToOpen {
        uint256 amount = bound(_amount, 1, mintPrice - 1);
        vm.prank(USER);
        vm.expectRevert(CoffeNFT.CoffeNft__NotEnoughEthSent.selector);
        coffeNft.requestNft{value: amount}(1);
    }

    // function testRevertsIfMaxAmountOfMintsReached() public setMintStatusToOpen {}

    // function testRevertsIfOutOfCofffe() public setMintStatusToOpen {}

    function testRequest() public setMintStatusToOpen {
        uint32 mintAmount = 2;
        uint256 amountBefore = coffeNft.balanceOf(USER);
        assertEq(amountBefore, 0);

        vm.prank(USER);
        (uint256 requestId) = coffeNft.requestNft{value: enough_mint_price * mintAmount}(mintAmount);

        assert(requestId > 0);

        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(requestId, address(coffeNft));
        uint256 amountAfter = coffeNft.balanceOf(USER);
        assertEq(amountAfter, mintAmount);
    }
}
