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
    // Events
    event NftRequested(uint256 indexed requestId, address requester);

    // Variables
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

    // Modifiers
    modifier setMintStatusToOpen() {
        address owner = coffeNft.owner();
        vm.prank(owner);
        coffeNft.setMintStatusOpen();
        _;
    }

    ///////////////////////
    // constructor TESTs //
    ///////////////////////
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

    //////////////////////
    // requestNft TESTs //
    //////////////////////
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

    function testRevertsIfMaxAmountOfMintsReachedMintingMaxMintAmountAtOnce() public setMintStatusToOpen {
        // checking the user balance before mint - should be 0
        uint256 startingMintAmount = coffeNft.balanceOf(USER);
        assertEq(startingMintAmount, 0);
        console.log(maxMintAmount);
        // requesting (minting) the max amount of NFTS
        vm.prank(USER);
        (uint256 requestId) = coffeNft.requestNft{value: enough_mint_price * maxMintAmount}(5);
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(requestId, address(coffeNft));
        // checking the user balance after mint - should be equal to maxMintAmount
        uint256 endingMintAmount = coffeNft.balanceOf(USER);
        console.log(endingMintAmount);
        assertEq(endingMintAmount, maxMintAmount);
        // requesting another NFTs - should revert because maxMintAmount already reached
        vm.prank(USER);
        vm.expectRevert(CoffeNFT.CoffeNft__MaxMintAmountReached.selector);
        coffeNft.requestNft{value: enough_mint_price}(1);
    }

    function testRevertsIfMaxAmountOfMintsReachedMintingMaxMintAmountNotAtOnce() public setMintStatusToOpen {
        // checking the user balance before mint - should be 0
        uint256 startingMintAmount = coffeNft.balanceOf(USER);
        assertEq(startingMintAmount, 0);
        console.log(maxMintAmount);
        // requesting (minting) 3 NFTS
        uint256 firstMintAmount = 3;
        vm.prank(USER);
        (uint256 requestIdFirst) =
            coffeNft.requestNft{value: enough_mint_price * firstMintAmount}(uint32(firstMintAmount));
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(requestIdFirst, address(coffeNft));
        // requesting (minting) 2 NFTS
        uint256 secondMintAmount = 2;
        vm.prank(USER);
        (uint256 requestIdSecond) =
            coffeNft.requestNft{value: enough_mint_price * secondMintAmount}(uint32(secondMintAmount));
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(requestIdSecond, address(coffeNft));
        // checking the user balance after mint - should be equal to firstMintAmount + secondMintAmount (which is max mint amount 5)
        uint256 endingMintAmount = coffeNft.balanceOf(USER);
        console.log(endingMintAmount);
        assertEq(endingMintAmount, firstMintAmount + secondMintAmount);
        // requesting another NFTs - should revert because maxMintAmount already reached
        vm.prank(USER);
        vm.expectRevert(CoffeNFT.CoffeNft__MaxMintAmountReached.selector);
        coffeNft.requestNft{value: enough_mint_price}(1);
    }

    function testRevertsIfOutOfCoffe() public setMintStatusToOpen {
        uint256 usersAmount = 20;
        for (uint256 i = 1; i < usersAmount + 1; i++) {
            address user = address(uint160(i));
            hoax(user, STARTING_BALANCE);
            (uint256 requestId) = coffeNft.requestNft{value: enough_mint_price * maxMintAmount}(uint32(maxMintAmount));
            VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(requestId, address(coffeNft));
        }
        address user21 = address(uint160(usersAmount + 1));
        uint256 tokenIds = coffeNft.getTokenIds();
        hoax(user21, STARTING_BALANCE);
        vm.expectRevert(abi.encodeWithSelector(CoffeNFT.CoffeNft__SorryWeAreOutOfCoffe.selector, tokenIds));
        coffeNft.requestNft{value: enough_mint_price}(1);
    }

    function testShouldEmitAnEventOnRequest() public setMintStatusToOpen {
        uint256 firstRequestId = 1; // we know the request Id will be 1 on Anvil test
        vm.expectEmit(true, false, false, false);
        emit NftRequested(firstRequestId, USER);
        vm.prank(USER);
        coffeNft.requestNft{value: enough_mint_price}(1);

        uint256 secondRequestId = 2; // we know the request Id will be 2
        vm.expectEmit(true, false, false, false);
        emit NftRequested(secondRequestId, USER2);
        vm.prank(USER2);
        coffeNft.requestNft{value: enough_mint_price}(1);
    }
    //////////////////////////////
    // fulfillRandomWords TESTs //
    //////////////////////////////

    function testShouldUpdateReservedSupplyIfCalledByMintReservedSupplyFunctionOneNft() public setMintStatusToOpen {
        uint256 startingReservedSupply = coffeNft.getReservedSupply();
        // only owner can call mintReservedSupply
        address owner = coffeNft.owner();
        uint32 mintAmount = 1;
        vm.prank(owner);
        (uint256 requestId) = coffeNft.mintReservedSupply(mintAmount);
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(requestId, address(coffeNft));
        uint256 endingReservedSupply = coffeNft.getReservedSupply();
        assertEq(startingReservedSupply - endingReservedSupply, mintAmount * 10 ** 18);
    }

    function testShouldUpdateReservedSupplyIfCalledByMintReservedSupplyFunctionMultipleNfts()
        public
        setMintStatusToOpen
    {
        uint256 startingReservedSupply = coffeNft.getReservedSupply();
        // only owner can call mintReservedSupply
        address owner = coffeNft.owner();
        uint32 firstMintAmount = 1;
        vm.startPrank(owner);
        (uint256 firstRequestId) = coffeNft.mintReservedSupply(firstMintAmount);
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(firstRequestId, address(coffeNft));

        uint32 secondMintAmount = 3;
        (uint256 secondRequestId) = coffeNft.mintReservedSupply(secondMintAmount);
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(secondRequestId, address(coffeNft));

        uint256 endingReservedSupply = coffeNft.getReservedSupply();
        assertEq(startingReservedSupply - endingReservedSupply, (firstMintAmount + secondMintAmount) * 10 ** 18);
    }

    function testShouldUpdateCallersBalanceOneNft() public setMintStatusToOpen {
        uint256 startingMintAmount = coffeNft.getMintAmount(USER);
        assertEq(startingMintAmount, 0);
        uint32 mintAmount = 1;
        vm.prank(USER);
        (uint256 requestId) = coffeNft.requestNft{value: enough_mint_price}(mintAmount);
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(requestId, address(coffeNft));
        uint256 endingMintAmount = coffeNft.getMintAmount(USER);
        assertEq(endingMintAmount, mintAmount);
        assertEq(endingMintAmount, coffeNft.balanceOf(USER));
    }

    function testShouldUpdateCallersBalanceMultipleNfts() public setMintStatusToOpen {
        uint256 startingMintAmount = coffeNft.getMintAmount(USER);
        assertEq(startingMintAmount, 0);
        uint32 firstMintAmount = 2;
        vm.startPrank(USER);
        (uint256 firstRequestId) = coffeNft.requestNft{value: enough_mint_price * firstMintAmount}(firstMintAmount);
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(firstRequestId, address(coffeNft));

        assertEq(firstMintAmount, coffeNft.balanceOf(USER));

        uint32 secondMintAmount = 3;
        (uint256 secondRequestId) = coffeNft.requestNft{value: enough_mint_price * secondMintAmount}(secondMintAmount);
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(secondRequestId, address(coffeNft));

        uint256 endingMintAmount = coffeNft.getMintAmount(USER);
        assertEq(endingMintAmount, firstMintAmount + secondMintAmount);
        assertEq(endingMintAmount, coffeNft.balanceOf(USER));
    }

    function testShouldNotUpdateReservedSupplyIfCalledByRequestNftFunction() public setMintStatusToOpen {
        uint256 startingReservedSupply = coffeNft.getReservedSupply();
        uint32 mintAmount = 1;
        vm.prank(USER);
        (uint256 requestId) = coffeNft.requestNft{value: enough_mint_price}(mintAmount);
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(requestId, address(coffeNft));
        uint256 endingReservedSupply = coffeNft.getReservedSupply();
        assertEq(startingReservedSupply, endingReservedSupply);
    }

    function testShouldNotUpdateOwnersMintAmountIfCalledBymintReservedSupplyFunction() public setMintStatusToOpen {
        address owner = coffeNft.owner();
        uint256 startingMintAmount = coffeNft.getMintAmount(owner);
        assertEq(startingMintAmount, 0);
        uint32 mintAmount = 1;
        vm.startPrank(owner);
        (uint256 requestId) = coffeNft.mintReservedSupply(mintAmount);
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(requestId, address(coffeNft));
        uint256 endingMintAmount = coffeNft.getMintAmount(owner);
        assertEq(startingMintAmount, endingMintAmount);
    }

    // function testShouldMintNftsToTheCaller() public setMintStatusToOpen {}
}
