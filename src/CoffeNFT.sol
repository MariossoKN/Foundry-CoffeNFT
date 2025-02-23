// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.19;

/**
 * @author Mariosso
 * @title CoffeNft
 * @notice This smart contract allows users to mint randomized coffee-themed NFTs using Chainlink VRF
 * for randomness. The contract reserves a supply of NFTs for the owner to mint.
 * The owner sets the mint price, total supply, maximum mint amount and reserved supply at deployment. Owner
 * can also change the minting status to pause the minting, update the token URI, and withdraw contract funds from contract.
 */
import {ERC721URIStorage, ERC721} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

contract CoffeNFT is VRFConsumerBaseV2Plus, ERC721URIStorage {
    /////////
    // Errors
    /////////
    error CoffeNft__NotEnoughEthSent();
    error CoffeNft__TransferFailed();
    error CoffeNft__FailedToRandomizeNft();
    error CoffeNft__MintNotActive();
    error CoffeNft__MaxMintAmountReached();
    error CoffeNft__ReservedSupplyHasToBeLess();
    error CoffeNft__SorryWeAreOutOfCoffe(uint256);
    error CoffeNft__WrongMintAmount();
    error CoffeNft__MaxMintAmountHasToBeLess();

    //////////////////
    // State variables
    //////////////////
    uint256 private tokenIds = 0;

    VRFConsumerBaseV2Plus private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane; // keyHash
    uint256 private immutable i_subId;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private immutable i_callbackGasLimit;
    uint256 private immutable i_mintPrice;
    uint256 private immutable i_totalSupply;
    uint256 private immutable i_maxMintAmount;
    uint256 private s_reservedSupply;
    bool private s_mintStatus;
    uint256 private s_reservedSupplyReqId = 0;
    address private s_owner;

    mapping(address owner => uint32 amountMinted) private s_ownerToTokenIds;
    mapping(uint256 requestId => address requester)
        private s_requestIdToAddress;

    /* URI */
    string internal s_tokenUri;

    /* Events */
    event NftRequested(uint256 indexed requestId, address requester);
    event NftMinted(uint256[] randomWords, string tokenUri, uint256 tokenId);

    /* Modifiers */
    modifier checkIfOwner() {
        require(msg.sender == s_owner, "Only owner can call this function");
        _;
    }

    ////////////
    // Functions
    ////////////
    constructor(
        address _vrfCoordinator,
        bytes32 _gasLane,
        uint256 _subId,
        uint32 _callbackGasLimit,
        uint256 _mintPrice,
        uint256 _totalSupply,
        uint256 _reservedSupply,
        uint256 _maxMintAmount,
        string memory _tokenUri
    ) ERC721("CoffeNFT", "COF") VRFConsumerBaseV2Plus(_vrfCoordinator) {
        if (_reservedSupply > _totalSupply)
            revert CoffeNft__ReservedSupplyHasToBeLess();
        if (
            _maxMintAmount > _totalSupply || (_maxMintAmount / 10 ** 18) > 500
        ) {
            revert CoffeNft__MaxMintAmountHasToBeLess();
        }
        i_gasLane = _gasLane;
        i_subId = _subId;
        i_callbackGasLimit = _callbackGasLimit;
        i_mintPrice = _mintPrice;
        i_totalSupply = _totalSupply;
        s_reservedSupply = _reservedSupply;
        i_maxMintAmount = _maxMintAmount;
        s_tokenUri = _tokenUri;
        s_owner = msg.sender;
    }

    /**
     * @dev caller can call this function with a input of X amount NFTs to mint (max i_maxMintAmount defined in constructor). This will request a X amount of random words from
     * the Chainlink VRF. Generates an requestId and pairs it with the address of the caller.
     * @dev caller has to send i_mintPrice * X amount of NFTs caller wants to mint.
     * @dev !!! Set the callbackGasLimit according to the max amount of NFTs to mint at once !!!
     * @param _mintAmount number of NFTs to mint / number of random words to request.
     */
    function requestNft(
        uint32 _mintAmount
    ) external payable returns (uint256 requestId) {
        if (_mintAmount <= 0 || _mintAmount > i_maxMintAmount) {
            revert CoffeNft__WrongMintAmount();
        }
        if (s_mintStatus == false) revert CoffeNft__MintNotActive();
        if (msg.value < (i_mintPrice * _mintAmount))
            revert CoffeNft__NotEnoughEthSent();
        if ((s_ownerToTokenIds[msg.sender] + _mintAmount) > i_maxMintAmount) {
            revert CoffeNft__MaxMintAmountReached();
        }
        if (
            (tokenIds * 10 ** 18 + (_mintAmount * 10 ** 18)) >
            i_totalSupply - s_reservedSupply
        ) {
            revert CoffeNft__SorryWeAreOutOfCoffe(tokenIds);
        }
        requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_gasLane,
                subId: i_subId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: _mintAmount,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );
        s_requestIdToAddress[requestId] = msg.sender;
        emit NftRequested(requestId, msg.sender);
    }

    /**
     * @dev called by the Chainlink VRF with X amount of random words and requestId.
     * @dev mints X amount of NFTs with random URIs to the address paired with the requestId. If called by the requestNft function, updates the
     * balance of the caller (s_ownerToTokenIds); if called by the mintReservedSupply function, updates the reserved supply (s_reservedSupply).
     * @param _requestId requestId from the requestNft function.
     * @param _randomWords X amount of random words from the Chainlink VRF.
     */
    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] calldata _randomWords
    ) internal override {
        address nftOwner = s_requestIdToAddress[_requestId];
        uint256 randomWordsLength = _randomWords.length;

        // updating the state variables after the fulfillment (not after request) in case the VRF request fails (for example in a case of low callbackGasLimit)
        if (s_reservedSupplyReqId == _requestId) {
            s_reservedSupply =
                s_reservedSupply -
                (randomWordsLength * 10 ** 18);
        } else {
            s_ownerToTokenIds[nftOwner] =
                s_ownerToTokenIds[nftOwner] +
                uint32(randomWordsLength);
        }

        for (uint256 i = 0; i < randomWordsLength; i++) {
            string memory tokenUri = pickRandomNft(_randomWords[i] % 100);
            // uint256 newTokenId = tokenIds;
            tokenIds++;
            _safeMint(nftOwner, tokenIds);
            _setTokenURI(tokenIds, tokenUri);
            emit NftMinted(_randomWords, tokenUri, tokenIds);
        }
    }

    /**
     * @dev assigns a random URI according to the mod of the random number generated by the VRF.
     * @param _randomNumber random number/s generated by the VRF.
     */
    function pickRandomNft(
        uint256 _randomNumber
    ) public view returns (string memory) {
        string memory tokenUri;
        if (_randomNumber <= 10) {
            tokenUri = string.concat(s_tokenUri, "/1.json");
        } else if (_randomNumber > 10 && _randomNumber <= 30) {
            tokenUri = string.concat(s_tokenUri, "/2.json");
        } else if (_randomNumber > 30 && _randomNumber <= 60) {
            tokenUri = string.concat(s_tokenUri, "/3.json");
        } else if (_randomNumber > 60 && _randomNumber <= 99) {
            tokenUri = string.concat(s_tokenUri, "/4.json");
        } else {
            revert CoffeNft__FailedToRandomizeNft();
        }
        return tokenUri;
    }

    /* Only owner functions */
    /**
     * @dev "requests" X amount of NFTs to be minted from the reserved supply. This function gets X amount of random words from the VRF. Generates an requestId and pairs it with the
     * caller. Also sets the reservedSupplyReqId so the fullfillRandomWords function recognizes that it is
     * called by the mintReservedSupply function. Only updates the reserved supply not the mintAmount of owner.
     * @dev !!! Keep in mind if the callbackGasLimit is set too low the whole reserved supply cant be minted in a single call but only in smaller batches !!!
     * @param _mintAmount number of NFTs to mint / number of random words to request.
     */
    function mintReservedSupply(
        uint32 _mintAmount
    ) public checkIfOwner returns (uint256 requestId) {
        if (_mintAmount > s_reservedSupply / 10 ** 18) {
            revert CoffeNft__SorryWeAreOutOfCoffe(s_reservedSupply);
        }
        requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_gasLane,
                subId: i_subId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: _mintAmount,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );
        s_requestIdToAddress[requestId] = msg.sender;
        s_reservedSupplyReqId = requestId;
        emit NftRequested(requestId, msg.sender);
    }

    // lets the owner of the contract to set the mint status to true which will open the mint
    function setMintStatusOpen() external checkIfOwner {
        s_mintStatus = true;
    }

    // lets the owner of the contract to set the mint status to false which will close the mint
    function setMintStatusClose() external checkIfOwner {
        s_mintStatus = false;
    }

    // lets the owner of the contract to set/change the token uri
    function setTokenUri(string memory _newTokenUri) public checkIfOwner {
        s_tokenUri = _newTokenUri;
    }

    // lets the owner of the contract to withdraw the funds from the contract
    function withdraw() public checkIfOwner {
        uint256 amount = address(this).balance;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) {
            revert CoffeNft__TransferFailed();
        }
    }

    // transfer ownership of the contract
    function transferOwnershipOfContract(address newOwner) public checkIfOwner {
        require(newOwner != address(0), "New owner cannot be the zero address");
        s_owner = newOwner;
    }

    /* View and Pure functions */
    function getVrfCoordinatorAddress() public view returns (address) {
        return address(s_vrfCoordinator);
    }

    function getMaxMintAmount() public view returns (uint256) {
        return i_maxMintAmount;
    }

    function getTokenIds() public view returns (uint256) {
        return tokenIds;
    }

    function getGasLane() public view returns (bytes32) {
        return i_gasLane;
    }

    function getSubId() public view returns (uint256) {
        return i_subId;
    }

    function getRequestConfirmations() public pure returns (uint16) {
        return REQUEST_CONFIRMATIONS;
    }

    function getCallbackGasLimit() public view returns (uint32) {
        return i_callbackGasLimit;
    }

    function getMintPrice() public view returns (uint256) {
        return i_mintPrice;
    }

    function getMintStatus() public view returns (bool) {
        return s_mintStatus;
    }

    function getTokenUris() public view returns (string memory) {
        return s_tokenUri;
    }

    function getMintAmount(address _address) public view returns (uint32) {
        return s_ownerToTokenIds[_address];
    }

    function getTotalSupply() public view returns (uint256) {
        return i_totalSupply;
    }

    function getReservedSupply() public view returns (uint256) {
        return s_reservedSupply;
    }

    function getCurrentSupply() public view returns (uint256) {
        return tokenIds * 10 ** 18;
    }

    function getOwnerAddress() public view returns (address) {
        return s_owner;
    }
}
