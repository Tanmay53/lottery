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
    DeployRaffle private deploy;

    // Events
    event EnteredRaffle(address indexed player);

    function setUp() external {
        deploy = new DeployRaffle();

        ( raffle, helperConfig ) = deploy.run();
        ( s_entry_fee ) = helperConfig.activeNetowrkConfig();

        vm.deal(s_player, STARTING_USER_BALANCE);
    }

    function testRaffleContractOwner() public {
        assertEq(raffle.getOwner(), msg.sender);
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
        console.log("Reverts when supplied with 0 entry_fee");

        vm.expectRevert(Raffle.Raffle_NotEnoughEthSent.selector);
        enterRaffle(s_player, s_entry_fee - 1);
        console.log("Reverts when supplied insufficient eth.");

        enterRaffleByPlayer();
        // Player exists in s_players array
        assertEq(raffle.getPlayer(0), s_player);
        console.log("Adds the first player to the raffle");

        // Checking contract balance
        assertEq(address(raffle).balance, s_entry_fee);
        console.log("Contract balance is equal to entry fee.");

        // Checking if no more than one player got added.
        vm.expectRevert();
        raffle.getPlayer(1);
        console.log("No more than one player added.");

        vm.expectEmit(true, false, false, false, address(raffle));
        emit Raffle.EnteredRaffle(s_player);
        enterRaffleByPlayer();
        console.log("Emits the Entered Raffle event.");
    }

    function testEntryWithExtraFee() public {
        uint original_player_balance = address(s_player).balance;

        enterRaffle(s_player, s_entry_fee + 1);

        assertEq(address(raffle).balance, s_entry_fee);

        uint new_player_balance = address(s_player).balance;

        assertEq(new_player_balance, original_player_balance - s_entry_fee);
    }

    function testEntryWithFeeInMultiples(uint no_of_entries, uint additional_fee) private {
        uint original_player_balance = address(s_player).balance;
        no_of_entries = no_of_entries + (additional_fee / s_entry_fee);
        additional_fee = additional_fee % s_entry_fee;

        enterRaffle(s_player, (no_of_entries * s_entry_fee) + additional_fee);

        assertEq(address(raffle).balance, no_of_entries * s_entry_fee);
        console.log("Raffle gets the entire fee sent to it");

        for( uint index = 0; index < no_of_entries; index++ ) {
            assertEq(raffle.getPlayer(index), s_player);
        }
        vm.expectRevert();
        raffle.getPlayer(no_of_entries + 1);
        console.log("%s entries recorded for the player", no_of_entries);

        assertEq(address(s_player).balance, original_player_balance - (no_of_entries * s_entry_fee));
        console.log("Correct amount available in the player's account");
    }

    function testEntryWithFeeInMultiplesOfEntryFee() public {
        testEntryWithFeeInMultiples(4, 0);
    }

    function testEntryWithFeeInMultiplesOfEntryFeeAndExtraFee() public {
        testEntryWithFeeInMultiples(5, s_entry_fee - 1);
    }

    function testEntryWithFeeInMultiplesOfEntryeFeeAndExtraFeeInMultiples() public {
        testEntryWithFeeInMultiples(5, (s_entry_fee * 2) + 1);
    }

    function testEntryWhileCalculating() public {

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

        console.log("Reverts because no eth sent");
        vm.expectRevert(Raffle.Raffle_NotEnoughEthSent.selector);
        raffle.pickWinner();

        uint pick_winner_fee = raffle.getPickWinnerFee();

        console.log("Reverts if only one player is there in the raffle");
        vm.expectRevert(Raffle.Raffle_NotEnoughPlayers.selector);
        raffle.pickWinner{value: pick_winner_fee}();

        enterRaffleMultipleByOwner(raffle.MIN_PLAYERS() - 1/*For first Player added earlier in the function*/ - 1/* One less than minimum player*/);

        pick_winner_fee = raffle.getPickWinnerFee();

        console.log("Reverts if the players are less than minimul allowed players");
        vm.expectRevert(Raffle.Raffle_NotEnoughPlayers.selector);
        raffle.pickWinner{value: pick_winner_fee}();

        enterRaffleByPlayer();

        console.log("Finally picks a winner with a valid call to pickWinner function");
        raffle.pickWinner{value: raffle.getPickWinnerFee()}();

        // Further testing of amounts sent to winners
    }

    function enterRaffleMultipleByOwner(uint count) internal {
        for(uint index = 0; index < count; index++) {
            enterRaffleByPlayer();
        }
    }

    // Check owner of the contract
    // test for : fund and receive global functions also
}