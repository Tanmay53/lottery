// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import { Raffle } from "../src/Raffle.sol";
import { Test, console } from "forge-std/Test.sol";
import { DeployRaffle } from "../script/DeployRaffle.s.sol";
import { HelperConfig } from "../script/HelperConfig.s.sol";

contract RaffleTest is Test {
    Raffle private raffle;
    HelperConfig private helperConfig;
    uint private s_entry_fee;

    address public s_player = makeAddr("player");
    uint public constant STARTING_USER_BALANCE = 10e18; // 10 ether

    function setUp() external {
        DeployRaffle deploy = new DeployRaffle();

        ( raffle, helperConfig ) = deploy.run();
        ( s_entry_fee ) = helperConfig.activeNetowrkConfig();

        vm.deal(s_player, STARTING_USER_BALANCE);
    }

    function testRaffleState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testEntryFee() public {
        assertEq(raffle.getEntranceFee(), s_entry_fee);
    }

    function testEntrySuccess() public {
        // Sending insufficient fee
        vm.expectRevert(Raffle.Raffle_NotEnoughEthSent.selector);
        enterRaffle(s_player, 0);
        vm.expectRevert(Raffle.Raffle_NotEnoughEthSent.selector);
        enterRaffle(s_player, s_entry_fee - 1);

        enterRaffleByPlayer();
        // Player exists in s_players array
        assertEq(raffle.getPlayer(0), s_player);

        // Checking contract balance
        assertEq(address(raffle).balance, s_entry_fee);

        // Checking if no more than one player got added.
        vm.expectRevert();
        raffle.getPlayer(1);
    }

    function testEntryWithExtraFee() public {
        uint original_player_balance = address(s_player).balance;

        enterRaffle(s_player, s_entry_fee + 1);

        assertEq(address(raffle).balance, s_entry_fee);

        uint new_player_balance = address(s_player).balance;

        assertEq(new_player_balance, original_player_balance - s_entry_fee);
    }

    // Enter address(this) to the raffle
    function enterRaffleByPlayer() internal {
        enterRaffle(s_player, s_entry_fee);
    }

    // Enter address(this) to the raffle
    function enterRaffle(address player, uint entry_fee) internal {
        vm.prank(player);
        raffle.enterRaffle{value: entry_fee}();
    }

    function testPickWinner() public {
        enterRaffleByPlayer();

        // Should revert if only one player is there in the raffle
        vm.expectRevert(Raffle.Raffle_NotEnoughPlayers.selector);
        raffle.pickWinner();

        enterRaffleMultipleByOwner(raffle.MIN_PLAYERS() - 1/*For first Player added earlier in the function*/ - 1/* One less than minimum player*/);

        // Should revent if the players are less than minimul allowed players
        vm.expectRevert();
        raffle.pickWinner();

        enterRaffleByPlayer();

        raffle.pickWinner();
    }

    function enterRaffleMultipleByOwner(uint count) internal {
        for(uint index = 0; index < count; index++) {
            enterRaffleByPlayer();
        }
    }
}