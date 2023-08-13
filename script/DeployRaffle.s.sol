// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import { Raffle } from "../src/Raffle.sol";
import { Script } from "forge-std/Script.sol";
import { HelperConfig } from "./HelperConfig.s.sol";

contract DeployRaffle is Script {
    uint public entry_fee;

    function run() external returns( Raffle, HelperConfig ) {
        HelperConfig helperConfig = new HelperConfig();
        ( entry_fee ) = helperConfig.activeNetowrkConfig();

        vm.startBroadcast();
        Raffle raffle = new Raffle(entry_fee);
        vm.stopBroadcast();

        return ( raffle, helperConfig );
    }
}