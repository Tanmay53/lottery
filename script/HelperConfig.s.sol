// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import { Script } from "forge-std/Script.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        uint entry_fee;
    }

    NetworkConfig public activeNetowrkConfig;

    constructor() {
        if( block.chainid == 11155111 ) {
            activeNetowrkConfig = getSepoliaEthConfig();
        }
        else {
            activeNetowrkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() public pure returns(NetworkConfig memory) {
        return NetworkConfig({
            entry_fee: 1e16 // 0.01 ether
        });
    }

    function getOrCreateAnvilEthConfig() public pure returns(NetworkConfig memory) {
        // Check if the mocks have already been deployed to the chain
        return NetworkConfig({
            entry_fee: 1e16 // 0.01 ether
        });
    }
}