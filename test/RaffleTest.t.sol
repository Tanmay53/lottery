// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import { Raffle } from "../src/Raffle.sol";
import { Test, console } from "forge-std/Test.sol";
import { DeployRaffle } from "../script/DeployRaffle.s.sol";

contract RaffleTest is Test {
    Raffle private raffle;
    uint private i_entry_fee;

    function setUp() external {
        DeployRaffle deploy = new DeployRaffle();
        raffle = deploy.run();
        i_entry_fee = deploy.ENTRY_FEE();
    }

    function testEntryFee() public {
        assertEq(raffle.getEntranceFee(), i_entry_fee);
    }

    function testEntrySuccess() public {
        enterRaffleByOwner();

        // Player exists in s_players array
        assertEq(raffle.s_players(0), address(this));

        // Checking contract balance
        assertEq(address(raffle).balance, i_entry_fee);

        // Checking if no more than one player got added.
        vm.expectRevert();
        raffle.s_players(1);
    }

    // Enter address(this) to the raffle
    function enterRaffleByOwner() internal {
        raffle.enterRaffle{value: i_entry_fee}();
    }

    function testPickWinner() public {
        enterRaffleByOwner();

        // Should revert if only one player is there in the raffle
        vm.expectRevert();
        raffle.pickWinner();

        enterRaffleMultipleByOwner(raffle.MIN_PLAYERS() - 1/*For first Player added earlier in the function*/ - 1/* One less than minimum player*/);

        // Should revent if the players are less than minimul allowed players
        vm.expectRevert();
        raffle.pickWinner();

        enterRaffleByOwner();

        address payable[] memory winners = raffle.pickWinner();

        for(uint index; index < winners.length; index++) {
            console.log(winners[index]);
        }
    }

    function enterRaffleMultipleByOwner(uint count) internal {
        for(uint index = 0; index < count; index++) {
            enterRaffleByOwner();
        }
    }
}