// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import { Raffle } from "../src/Raffle.sol";
import { Script } from "forge-std/Script.sol";

contract DeployRaffle is Script {
    uint public constant ENTRY_FEE = 1e16;

    function run() external returns( Raffle ) {
        return new Raffle(ENTRY_FEE);
    }
}