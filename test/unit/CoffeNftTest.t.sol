// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {CoffeNFT} from "../../src/CoffeNFT.sol";
import {DeployCoffeNFT} from "../../script/DeployCoffeNFT.s.sol";
import {Vm} from "../../lib/forge-std/src/Vm.sol";
import {Test, console} from "../../lib/forge-std/src/Test.sol";
import {VRFCoordinatorV2_5Mock} from "../../test/mock/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../../test/mock/LinkToken.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract CoffeNftTest is Test {
    // Events
    event NftRequested(uint256 indexed requestId, address requester);
    event NftMinted(uint256[] randomWords, string tokenUri, uint256 tokenId);

    // Variables
    CoffeNFT public coffeNft;
    VRFCoordinatorV2_5Mock public vrfCoordinatorV2_5Mock;
    LinkToken public linkToken;
    DeployCoffeNFT public deployCoffeNft;
    HelperConfig public helperConfig;
    Ownable public ownable;

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
    address owner;

    uint256 constant STARTING_BALANCE = 20 ether;
    uint256 enough_mint_price;
    uint256 not_enough_mint_price;

    function setUp() external {
        deployCoffeNft = new DeployCoffeNFT();
        (coffeNft, helperConfig) = deployCoffeNft.run();
        // reading the config data twice to prevent stack too deep error
        (
            vrfCoordinator,
            gasLane,
            subId,
            callbackGasLimit,
            mintPrice,
            totalSupply,
            reservedSupply,
            ,
            ,
            ,

        ) = helperConfig.activeNetworkConfig();
        (
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            maxMintAmount,
            tokenUri,
            link,
            deployerKey
        ) = helperConfig.activeNetworkConfig();
        owner = coffeNft.owner();
        enough_mint_price = mintPrice;
        not_enough_mint_price = mintPrice - 1;
        vm.deal(USER, STARTING_BALANCE);
        vm.deal(USER2, STARTING_BALANCE);
    }

    // Modifiers
    modifier setMintStatusToOpen() {
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
        assert(coffeNft.getSubId() > 0);
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

    function testFuzzMintAmountCantBeMoreThanMaxMintAmount(
        uint32 _amount
    ) public setMintStatusToOpen {
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

    function testRevertsIfNotEnoughEthSentWithOneRequest()
        public
        setMintStatusToOpen
    {
        vm.prank(USER);
        vm.expectRevert(CoffeNFT.CoffeNft__NotEnoughEthSent.selector);
        coffeNft.requestNft{value: not_enough_mint_price}(1);
    }

    function testRevertsIfNotEnoughEthSentWithMultpleRequests()
        public
        setMintStatusToOpen
    {
        uint32 amountMinted = 4;
        vm.prank(USER);
        vm.expectRevert(CoffeNFT.CoffeNft__NotEnoughEthSent.selector);
        coffeNft.requestNft{value: not_enough_mint_price * amountMinted}(
            amountMinted
        );
    }

    function testFuzzRevertsIfNotEnoughEthSent(
        uint256 _amount
    ) public setMintStatusToOpen {
        uint256 amount = bound(_amount, 1, mintPrice - 1);
        vm.prank(USER);
        vm.expectRevert(CoffeNFT.CoffeNft__NotEnoughEthSent.selector);
        coffeNft.requestNft{value: amount}(1);
    }

    function testRevertsIfMaxAmountOfMintsReachedMintingMaxMintAmountAtOnce()
        public
        setMintStatusToOpen
    {
        // checking the user balance before mint - should be 0
        uint256 startingMintAmount = coffeNft.balanceOf(USER);
        assertEq(startingMintAmount, 0);
        console.log(maxMintAmount);
        // requesting (minting) the max amount of NFTS
        vm.prank(USER);
        uint256 requestId = coffeNft.requestNft{
            value: enough_mint_price * maxMintAmount
        }(5);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            requestId,
            address(coffeNft)
        );
        // checking the user balance after mint - should be equal to maxMintAmount
        uint256 endingMintAmount = coffeNft.balanceOf(USER);
        console.log(endingMintAmount);
        assertEq(endingMintAmount, maxMintAmount);
        // requesting another NFTs - should revert because maxMintAmount already reached
        vm.prank(USER);
        vm.expectRevert(CoffeNFT.CoffeNft__MaxMintAmountReached.selector);
        coffeNft.requestNft{value: enough_mint_price}(1);
    }

    function testRevertsIfMaxAmountOfMintsReachedMintingMaxMintAmountNotAtOnce()
        public
        setMintStatusToOpen
    {
        // checking the user balance before mint - should be 0
        uint256 startingMintAmount = coffeNft.balanceOf(USER);
        assertEq(startingMintAmount, 0);
        console.log(maxMintAmount);
        // requesting (minting) 3 NFTS
        uint256 firstMintAmount = 3;
        vm.prank(USER);
        uint256 requestIdFirst = coffeNft.requestNft{
            value: enough_mint_price * firstMintAmount
        }(uint32(firstMintAmount));
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            requestIdFirst,
            address(coffeNft)
        );
        // requesting (minting) 2 NFTS
        uint256 secondMintAmount = 2;
        vm.prank(USER);
        uint256 requestIdSecond = coffeNft.requestNft{
            value: enough_mint_price * secondMintAmount
        }(uint32(secondMintAmount));
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            requestIdSecond,
            address(coffeNft)
        );
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
        uint256 usersAmount = 17;

        for (uint256 i = 1; i < usersAmount + 1; i++) {
            address user = address(uint160(i));
            hoax(user, STARTING_BALANCE);
            uint256 requestId = coffeNft.requestNft{
                value: enough_mint_price * maxMintAmount
            }(uint32(maxMintAmount));
            VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
                requestId,
                address(coffeNft)
            );
        }

        address user18 = address(uint160(usersAmount + 1));
        uint256 tokenIds = coffeNft.getTokenIds();
        hoax(user18, STARTING_BALANCE);
        vm.expectRevert(
            abi.encodeWithSelector(
                CoffeNFT.CoffeNft__SorryWeAreOutOfCoffe.selector,
                tokenIds
            )
        );
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
    function testShouldUpdateReservedSupplyIfCalledByMintReservedSupplyFunctionOneNft()
        public
        setMintStatusToOpen
    {
        uint256 startingReservedSupply = coffeNft.getReservedSupply();
        // only owner can call mintReservedSupply
        uint32 mintAmount = 1;

        vm.prank(owner);
        uint256 requestId = coffeNft.mintReservedSupply(mintAmount);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            requestId,
            address(coffeNft)
        );
        uint256 endingReservedSupply = coffeNft.getReservedSupply();

        assertEq(
            startingReservedSupply - endingReservedSupply,
            mintAmount * 10 ** 18
        );
    }

    function testShouldUpdateReservedSupplyIfCalledByMintReservedSupplyFunctionMultipleNfts()
        public
        setMintStatusToOpen
    {
        uint256 startingReservedSupply = coffeNft.getReservedSupply();
        // only owner can call mintReservedSupply
        uint32 firstMintAmount = 1;
        vm.startPrank(owner);
        uint256 firstRequestId = coffeNft.mintReservedSupply(firstMintAmount);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            firstRequestId,
            address(coffeNft)
        );

        uint32 secondMintAmount = 3;
        uint256 secondRequestId = coffeNft.mintReservedSupply(secondMintAmount);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            secondRequestId,
            address(coffeNft)
        );

        uint256 endingReservedSupply = coffeNft.getReservedSupply();
        assertEq(
            startingReservedSupply - endingReservedSupply,
            (firstMintAmount + secondMintAmount) * 10 ** 18
        );
    }

    function testShouldUpdateCallersBalanceOneNft() public setMintStatusToOpen {
        uint256 startingMintAmount = coffeNft.getMintAmount(USER);
        assertEq(startingMintAmount, 0);
        uint32 mintAmount = 1;

        vm.prank(USER);
        uint256 requestId = coffeNft.requestNft{value: enough_mint_price}(
            mintAmount
        );
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            requestId,
            address(coffeNft)
        );
        uint256 endingMintAmount = coffeNft.getMintAmount(USER);

        assertEq(endingMintAmount, mintAmount);
        assertEq(endingMintAmount, coffeNft.balanceOf(USER));
    }

    function testShouldUpdateCallersBalanceMultipleNfts()
        public
        setMintStatusToOpen
    {
        uint256 startingMintAmount = coffeNft.getMintAmount(USER);
        assertEq(startingMintAmount, 0);
        uint32 firstMintAmount = 2;
        vm.startPrank(USER);
        uint256 firstRequestId = coffeNft.requestNft{
            value: enough_mint_price * firstMintAmount
        }(firstMintAmount);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            firstRequestId,
            address(coffeNft)
        );

        assertEq(firstMintAmount, coffeNft.balanceOf(USER));

        uint32 secondMintAmount = 3;
        uint256 secondRequestId = coffeNft.requestNft{
            value: enough_mint_price * secondMintAmount
        }(secondMintAmount);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            secondRequestId,
            address(coffeNft)
        );

        uint256 endingMintAmount = coffeNft.getMintAmount(USER);
        assertEq(endingMintAmount, firstMintAmount + secondMintAmount);
        assertEq(endingMintAmount, coffeNft.balanceOf(USER));
    }

    function testShouldNotUpdateReservedSupplyIfCalledByRequestNftFunction()
        public
        setMintStatusToOpen
    {
        uint256 startingReservedSupply = coffeNft.getReservedSupply();
        uint32 mintAmount = 1;

        vm.prank(USER);
        uint256 requestId = coffeNft.requestNft{value: enough_mint_price}(
            mintAmount
        );
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            requestId,
            address(coffeNft)
        );
        uint256 endingReservedSupply = coffeNft.getReservedSupply();

        assertEq(startingReservedSupply, endingReservedSupply);
    }

    function testShouldNotUpdateOwnersMintAmountIfCalledBymintReservedSupplyFunction()
        public
        setMintStatusToOpen
    {
        uint256 startingMintAmount = coffeNft.getMintAmount(owner);
        assertEq(startingMintAmount, 0);

        uint32 mintAmount = 1;
        vm.startPrank(owner);
        uint256 requestId = coffeNft.mintReservedSupply(mintAmount);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            requestId,
            address(coffeNft)
        );
        uint256 endingMintAmount = coffeNft.getMintAmount(owner);

        assertEq(startingMintAmount, endingMintAmount);
    }

    function testShouldMintNftsToTheCallerUsingRequestNftFunctionOneNft()
        public
        setMintStatusToOpen
    {
        uint256 startingBalance = coffeNft.balanceOf(USER);
        assertEq(startingBalance, 0);
        assertEq(startingBalance, coffeNft.getMintAmount(USER));
        assertEq(coffeNft.getCurrentSupply(), 0);
        uint32 mintAmount = 4;

        vm.prank(USER);
        uint256 requestId = coffeNft.requestNft{
            value: enough_mint_price * mintAmount
        }(mintAmount);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            requestId,
            address(coffeNft)
        );
        uint256 endingBalance = coffeNft.balanceOf(USER);

        assertEq(endingBalance, mintAmount);
        assertEq(endingBalance, coffeNft.getMintAmount(USER));
        assertEq(coffeNft.getCurrentSupply(), mintAmount * 10 ** 18);
    }

    function testShouldMintNftsToTheCallerUsingRequestNftFunctionMultipleNfts()
        public
        setMintStatusToOpen
    {
        uint256 startingBalance = coffeNft.balanceOf(USER);
        assertEq(startingBalance, 0);
        assertEq(startingBalance, coffeNft.getMintAmount(USER));
        assertEq(coffeNft.getCurrentSupply(), 0);
        uint32 firstMintAmount = 1;

        vm.startPrank(USER);
        uint256 firstRequestId = coffeNft.requestNft{value: enough_mint_price}(
            firstMintAmount
        );
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            firstRequestId,
            address(coffeNft)
        );

        assertEq(firstMintAmount, coffeNft.balanceOf(USER));

        uint32 secondMintAmount = 3;

        uint256 secondRequestId = coffeNft.requestNft{
            value: enough_mint_price * secondMintAmount
        }(secondMintAmount);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            secondRequestId,
            address(coffeNft)
        );
        uint256 endingBalance = coffeNft.balanceOf(USER);

        assertEq(endingBalance, firstMintAmount + secondMintAmount);
        assertEq(endingBalance, coffeNft.getMintAmount(USER));
        assertEq(
            coffeNft.getCurrentSupply(),
            (firstMintAmount + secondMintAmount) * 10 ** 18
        );
    }

    function testShouldMintNftsToTheCallerUsingMintReservedSupplyFunctionOneNft()
        public
        setMintStatusToOpen
    {
        uint256 startingBalance = coffeNft.balanceOf(owner);
        assertEq(startingBalance, 0);
        assertEq(coffeNft.getCurrentSupply(), 0);
        uint32 mintAmount = 1;

        vm.startPrank(owner);
        uint256 requestId = coffeNft.mintReservedSupply(mintAmount);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            requestId,
            address(coffeNft)
        );
        uint256 endingBalance = coffeNft.balanceOf(owner);

        assertEq(endingBalance, mintAmount);
        assertEq(coffeNft.getCurrentSupply(), mintAmount * 10 ** 18);
    }

    function testShouldMintNftsToTheCallerUsingMintReservedSupplyFunctionMultipleNfts()
        public
        setMintStatusToOpen
    {
        uint256 startingBalance = coffeNft.balanceOf(owner);
        assertEq(startingBalance, 0);
        assertEq(coffeNft.getCurrentSupply(), 0);
        uint32 firstMintAmount = 5;

        vm.startPrank(owner);
        uint256 firstRequestId = coffeNft.mintReservedSupply(firstMintAmount);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            firstRequestId,
            address(coffeNft)
        );

        assertEq(coffeNft.getCurrentSupply(), firstMintAmount * 10 ** 18);

        uint32 secondMintAmount = 4;

        uint256 secondRequestId = coffeNft.mintReservedSupply(secondMintAmount);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            secondRequestId,
            address(coffeNft)
        );
        uint256 endingBalance = coffeNft.balanceOf(owner);

        assertEq(endingBalance, firstMintAmount + secondMintAmount);
        assertEq(
            coffeNft.getCurrentSupply(),
            (firstMintAmount + secondMintAmount) * 10 ** 18
        );
    }

    function testShouldAssaignAnTokenUriToMintedTokenUsingRequestNftFunction()
        public
        setMintStatusToOpen
    {
        vm.expectRevert();
        coffeNft.tokenURI(1);

        string
            memory expectedUri = "ipfs://bafybeih73omsfk6rzjp4hsviaxa2ucpchnnnxpb2bzvgf4dakwbod2rll4/4.json";

        vm.prank(USER);
        uint256 requestId = coffeNft.requestNft{value: enough_mint_price}(1);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            requestId,
            address(coffeNft)
        );
        string memory tokenURI = coffeNft.tokenURI(1);

        assertEq0(bytes(tokenURI), bytes(expectedUri));
    }

    function testShouldAssaignAnTokenUriToMintedTokenUsingMintReservedSupplyFunction()
        public
        setMintStatusToOpen
    {
        vm.expectRevert();
        coffeNft.tokenURI(1);

        string
            memory expectedUri = "ipfs://bafybeih73omsfk6rzjp4hsviaxa2ucpchnnnxpb2bzvgf4dakwbod2rll4/4.json";

        vm.startPrank(owner);
        uint256 firstRequestId = coffeNft.mintReservedSupply(1);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            firstRequestId,
            address(coffeNft)
        );
        string memory tokenURI = coffeNft.tokenURI(1);

        assertEq0(bytes(tokenURI), bytes(expectedUri));
    }

    // function testShouldEmitAnEventAfterMint() public setMintStatusToOpen {
    //     vm.expectEmit(true, false, false, false);
    //     emit NftMinted();
    //     vm.prank(USER);
    //     coffeNft.requestNft{value: enough_mint_price}(1);
    // }

    /////////////////////////
    // pickRandomNft TESTs //
    /////////////////////////
    function testFuzzShouldAssignFirstUriIfNumberIsLessOrEqualTen(
        uint256 _number
    ) public view {
        uint256 number = bound(_number, 0, 10);

        string
            memory expectedUri = "ipfs://bafybeih73omsfk6rzjp4hsviaxa2ucpchnnnxpb2bzvgf4dakwbod2rll4/1.json";
        string memory tokenURI = coffeNft.pickRandomNft(number);

        assertEq0(bytes(tokenURI), bytes(expectedUri));
    }

    function testFuzzShouldAssignSecondtUriIfNumberIsLessOrEqualThirtyButMoreThanTen(
        uint256 _number
    ) public view {
        uint256 number = bound(_number, 11, 30);

        string
            memory expectedUri = "ipfs://bafybeih73omsfk6rzjp4hsviaxa2ucpchnnnxpb2bzvgf4dakwbod2rll4/2.json";
        string memory tokenURI = coffeNft.pickRandomNft(number);

        assertEq0(bytes(tokenURI), bytes(expectedUri));
    }

    function testFuzzShouldAssignThirdUriIfNumberIsLessOrEqualSixtyButMoreThanThirty(
        uint256 _number
    ) public view {
        uint256 number = bound(_number, 31, 60);

        string
            memory expectedUri = "ipfs://bafybeih73omsfk6rzjp4hsviaxa2ucpchnnnxpb2bzvgf4dakwbod2rll4/3.json";
        string memory tokenURI = coffeNft.pickRandomNft(number);

        assertEq0(bytes(tokenURI), bytes(expectedUri));
    }

    function testFuzzShouldAssignFourthUriIfNumberIsLessOrEqualNinetyNineButMoreThanSixty(
        uint256 _number
    ) public view {
        uint256 number = bound(_number, 61, 99);

        string
            memory expectedUri = "ipfs://bafybeih73omsfk6rzjp4hsviaxa2ucpchnnnxpb2bzvgf4dakwbod2rll4/4.json";
        string memory tokenURI = coffeNft.pickRandomNft(number);

        assertEq0(bytes(tokenURI), bytes(expectedUri));
    }

    function testShoulRevertIfNumberIsGreaterThanNinetyNine(
        uint256 _number
    ) public {
        uint256 number = bound(_number, 100, type(uint256).max);

        vm.expectRevert(CoffeNFT.CoffeNft__FailedToRandomizeNft.selector);
        coffeNft.pickRandomNft(number);
    }

    //////////////////////////////
    // mintReservedSupply TESTs //
    //////////////////////////////
    function testShouldRevertIfNotCalledByOwner() public {
        vm.prank(USER);
        vm.expectRevert("Only owner can call this function");
        coffeNft.mintReservedSupply(1);
    }

    function testFuzzShouldRevertIfTheMintedAmountIsGreaterThanRemainingReservedSupply(
        uint32 _amount
    ) public {
        uint256 resSupply = coffeNft.getReservedSupply(); // 15000000000000000000

        uint256 amount = bound(
            _amount,
            (resSupply / 10 ** 18) + 1,
            type(uint32).max
        );

        vm.prank(owner);

        vm.expectRevert(
            abi.encodeWithSelector(
                CoffeNFT.CoffeNft__SorryWeAreOutOfCoffe.selector,
                resSupply
            )
        );
        coffeNft.mintReservedSupply(uint32(amount));
    }

    function testShouldRevertIfTheWholeReservedSupplyIsMinted() public {
        uint256 resSupply = coffeNft.getReservedSupply(); // 15000000000000000000

        vm.startPrank(owner);

        uint256 requestId = coffeNft.mintReservedSupply(
            uint32(resSupply / 10 ** 18)
        ); // !!! keep in mind that if the callbackGasLimit is set to low this will fail with OutOfGas error and the reserved supply has to be minted in batches and not in single call
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            requestId,
            address(coffeNft)
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                CoffeNFT.CoffeNft__SorryWeAreOutOfCoffe.selector,
                0
            )
        );
        coffeNft.mintReservedSupply(1);
    }

    function testShouldEmitAnEventAfterCall() public {
        uint256 firstRequestId = 1; // we know the request Id will be 1 on Anvil test

        vm.expectEmit(true, false, false, false);
        emit NftRequested(firstRequestId, owner);
        vm.startPrank(owner);
        coffeNft.mintReservedSupply(uint32(1));

        uint256 secondRequestId = 2; // we know the request Id will be 2
        vm.expectEmit(true, false, false, false);
        emit NftRequested(secondRequestId, owner);
        coffeNft.mintReservedSupply(uint32(1));
    }

    function testShouldMintNftsToOwnerAndUpdateReservedSupply()
        public
        setMintStatusToOpen
    {
        uint256 startingOwnerBalance = coffeNft.balanceOf(owner); // 0
        uint256 startingReservedSupply = coffeNft.getReservedSupply(); // 15000000000000000000
        uint32 firstMintAmount = 1;

        vm.startPrank(owner);
        uint256 firstRequestId = coffeNft.mintReservedSupply(firstMintAmount);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            firstRequestId,
            address(coffeNft)
        );

        assertEq(
            coffeNft.balanceOf(owner),
            startingOwnerBalance + firstMintAmount
        ); // 1 , 0 + 1
        assertEq(
            coffeNft.getReservedSupply(),
            startingReservedSupply - (firstMintAmount * 10 ** 18)
        ); // 14000000000000000000 , 15000000000000000000 - 1000000000000000000

        uint32 secondMintAmount = 4;
        uint256 secondRequestId = coffeNft.mintReservedSupply(secondMintAmount);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            secondRequestId,
            address(coffeNft)
        );

        assertEq(
            coffeNft.balanceOf(owner),
            startingOwnerBalance + firstMintAmount + secondMintAmount
        );
        assertEq(
            coffeNft.getReservedSupply(),
            startingReservedSupply -
                (firstMintAmount * 10 ** 18) -
                (secondMintAmount * 10 ** 18)
        );
        vm.stopPrank();

        // checking if owner can still mint trough the requestNft function (payable)
        uint32 thirdMintAmount = 1;
        assertEq(coffeNft.getMintAmount(owner), 0);

        hoax(owner, STARTING_BALANCE);
        uint256 thirdRequestId = coffeNft.requestNft{value: enough_mint_price}(
            thirdMintAmount
        );
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            thirdRequestId,
            address(coffeNft)
        );

        assertEq(coffeNft.getMintAmount(owner), 1);
        assertEq(
            coffeNft.balanceOf(owner),
            startingOwnerBalance +
                firstMintAmount +
                secondMintAmount +
                thirdMintAmount
        );
    }

    ////////////////////////////
    // setMintStatusOpen TEST //
    ////////////////////////////
    function testShouldRevertIfNotCalledByOwnerOpen() public {
        vm.prank(USER);
        vm.expectRevert("Only owner can call this function");
        coffeNft.setMintStatusOpen();
    }

    function testIfSetToOpenUsersCanRequestNftAndMintStatusHasToBeTrue()
        public
    {
        assertEq(coffeNft.getMintStatus(), false);

        vm.prank(owner);
        coffeNft.setMintStatusOpen();

        uint32 amountMinted = 4;
        vm.prank(USER);
        uint256 requestId = coffeNft.requestNft{
            value: enough_mint_price * amountMinted
        }(amountMinted);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            requestId,
            address(coffeNft)
        );

        assertEq(coffeNft.getMintAmount(USER), amountMinted);
        assertEq(coffeNft.getMintStatus(), true);
    }

    /////////////////////////////
    // setMintStatusClose TEST //
    /////////////////////////////
    function testShouldRevertIfNotCalledByOwnerClose() public {
        vm.prank(USER);
        vm.expectRevert("Only owner can call this function");
        coffeNft.setMintStatusClose();
    }

    function testIfSetToCloseUsersCantRequestNftAndMintStatusHasToBeFalse()
        public
        setMintStatusToOpen
    {
        assertEq(coffeNft.getMintStatus(), true);

        vm.prank(owner);
        coffeNft.setMintStatusClose();

        uint32 amountMinted = 4;
        vm.prank(USER);

        vm.expectRevert(CoffeNFT.CoffeNft__MintNotActive.selector);
        coffeNft.requestNft{value: enough_mint_price * amountMinted}(
            amountMinted
        );

        assertEq(coffeNft.getMintStatus(), false);
    }

    ///////////////////////
    // setTokenUri TESTs //
    ///////////////////////
    function testShouldRevertIfCalledByNotOwnerToSetUri() public {
        vm.prank(USER);
        vm.expectRevert("Only owner can call this function");
        coffeNft.setTokenUri("newUri");
    }

    function testShouldSetToNewUri() public setMintStatusToOpen {
        vm.prank(owner);

        coffeNft.setTokenUri("newUri");

        vm.prank(USER);
        uint256 firstRequestId = coffeNft.requestNft{value: enough_mint_price}(
            1
        );
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            firstRequestId,
            address(coffeNft)
        );

        vm.prank(owner);
        uint256 secondRequestId = coffeNft.mintReservedSupply(1);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            secondRequestId,
            address(coffeNft)
        );

        assertEq(coffeNft.tokenURI(1), "newUri/4.json");
        assertEq(coffeNft.tokenURI(2), "newUri/2.json");
        assertEq(coffeNft.getTokenUris(), "newUri");
    }

    ///////////////////
    // withdraw TEST //
    ///////////////////
    function testShouldRevertIfNotCalledByOwnerToWithdraw() public {
        vm.prank(USER);
        vm.expectRevert("Only owner can call this function");
        coffeNft.withdraw();
    }

    function testShouldWithdrawAllEthFromContractToOwner()
        public
        setMintStatusToOpen
    {
        uint256 startingOwnerBalance = owner.balance;

        uint256 usersAmount = 10;
        for (uint256 i = 1; i < usersAmount + 1; i++) {
            address user = address(uint160(i));
            hoax(user, STARTING_BALANCE);
            uint256 requestId = coffeNft.requestNft{
                value: enough_mint_price * maxMintAmount
            }(uint32(maxMintAmount));
            VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
                requestId,
                address(coffeNft)
            );
        }

        vm.prank(owner);
        coffeNft.withdraw();

        uint256 endingContractBalance = address(coffeNft).balance;
        uint256 endingOwnerBalance = owner.balance;

        assertEq(endingContractBalance, 0);
        assertEq(
            endingOwnerBalance,
            startingOwnerBalance +
                usersAmount *
                (enough_mint_price * maxMintAmount)
        );
    }

    //////////////////////////////////////
    // transferOwnershipOfContract TEST //
    //////////////////////////////////////
    function testShouldAllowOwnerToTransferOwnership() public {
        address newOwner = makeAddr("newOwner");
        vm.prank(owner);
        coffeNft.transferOwnershipOfContract(newOwner);

        assertEq(coffeNft.getOwnerAddress(), newOwner);
    }

    function testShouldRevertIfCalledByNotOwnerToTransferOwnership() public {
        address newOwner = makeAddr("newOwner");
        vm.prank(USER);
        vm.expectRevert("Only owner can call this function");
        coffeNft.transferOwnershipOfContract(newOwner);
    }

    function testShouldRevertIfNewOwnerIsZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert("New owner cannot be the zero address");
        coffeNft.transferOwnershipOfContract(address(0));
    }

    //////////////////////////////////
    // getRequestConfirmations TEST //
    //////////////////////////////////
    function testShouldGetRequestConfirmations() public view {
        assertEq(coffeNft.getRequestConfirmations(), 3);
    }
}
