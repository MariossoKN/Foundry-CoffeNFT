// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {CoffeNFT} from "../../src/CoffeNFT.sol";
import {Script} from "../../lib/forge-std/src/Script.sol";
import {VRFCoordinatorV2Mock} from "../../test/mock/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../../test/mock/LinkToken.sol";

contract CoffeNftTest is Script {}
