// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { Raffle } from "../src/Raffle.sol";
import { Test, console } from "forge-std/Test.sol";
import { DeployRaffle } from "../script/DeployRaffle.s.sol";
import { HelperConfig } from "../script/HelperConfig.s.sol";
import { stdError } from "forge-std/StdError.sol";
import { Vm } from "forge-std/Vm.sol";
import { Strings } from "@openzeppelin/utils/Strings.sol";

contract Reverter {
    bool dontRevert = false;

    receive() external payable {
        if( !dontRevert ) {
            revert();
        }
    }

    fallback() external payable {
        if( !dontRevert ) {
            revert();
        }
    }

    function toggleReverting() external {
        dontRevert = !dontRevert;
    }
}

contract RaffleTest is Test {
    Raffle private raffle;
    HelperConfig private helperConfig;
    uint private s_entry_fee;

    address public s_player = makeAddr("player");
    uint public constant STARTING_USER_BALANCE = 10e18; // 10 ether
    DeployRaffle private deploy;
    uint public constant RANDOM_PLAYER_COUNT = 30;
    address[RANDOM_PLAYER_COUNT] public s_players;
    uint constant POSITION_COUNT = 10;

    Reverter public reverter;

    // Events
    event EnteredRaffle(address indexed player);

    function setUp() external {
        deploy = new DeployRaffle();

        ( raffle, helperConfig ) = deploy.run();
        ( s_entry_fee ) = helperConfig.activeNetowrkConfig();

        vm.deal(s_player, STARTING_USER_BALANCE);

        for( uint index; index < RANDOM_PLAYER_COUNT; index++ ) {
            s_players[index] = makeAddr(string.concat("player_", Strings.toString(index)));
            vm.deal(s_players[index], STARTING_USER_BALANCE);
        }

        reverter = new Reverter();
        vm.deal(address(reverter), STARTING_USER_BALANCE);
    }

    function testRaffleContractOwner() public {
        assertEq(raffle.getOwner(), msg.sender);
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
        assertEq(raffle.getPlayer(0, 0), s_player);
        console.log("Adds the first player to the raffle");

        // Checking contract balance
        assertEq(address(raffle).balance, s_entry_fee);
        console.log("Contract balance is equal to entry fee.");

        // Checking if no more than one player got added.
        vm.expectRevert(stdError.indexOOBError);
        raffle.getPlayer(0, 1);
        console.log("No more than one player added.");

        vm.recordLogs();
        enterRaffleByPlayer();
        Vm.Log[] memory entries = vm.getRecordedLogs();

        if( keccak256("EnteredRaffle(uint256,address)") == entries[0].topics[0] )
        {
            assertEq(uint(entries[0].topics[1]), 0);
            assertEq(abi.decode(abi.encodePacked(entries[0].topics[2]), (address)), s_player);
        }
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
            assertEq(raffle.getPlayer(0, index), s_player);
        }
        vm.expectRevert(stdError.indexOOBError);
        raffle.getPlayer(0, no_of_entries + 1);
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

    function testEntryWhileCalculating() public view {

    }

    // Enter address(this) to the raffle
    function enterRaffleByPlayer() internal {
        enterRaffle(s_player, s_entry_fee);
    }

    // Enter address(this) to the raffle
    function enterRaffle(address player, uint entry_fee) internal {
        vm.prank(player);
        raffle.enterRaffle{value: entry_fee}(0);
    }

    function testPickWinner() public {
        uint original_player_balance = address(s_player).balance;

        enterRaffleByPlayer();

        vm.expectRevert(Raffle.Raffle_NotEnoughEthSent.selector);
        raffle.pickWinner(0);
        console.log("Reverts because no eth sent");

        uint pick_winner_fee = raffle.getPickWinnerFee(0);

        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle_NotEnoughPlayers.selector, 0)
        );
        raffle.pickWinner{value: pick_winner_fee}(0);
        console.log("Reverts if only one player is there in the raffle");

        enterRaffleMultipleByPlayer(raffle.MIN_PLAYERS() - 1/*For first Player added earlier in the function*/ - 1/* One less than minimum player*/);

        pick_winner_fee = raffle.getPickWinnerFee(0);

        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle_NotEnoughPlayers.selector, 0)
        );
        raffle.pickWinner{value: pick_winner_fee}(0);
        console.log("Reverts if the players are less than minimum allowed players");

        enterRaffleByPlayer();

        vm.startPrank(msg.sender);
        pick_winner_fee = raffle.getPickWinnerFee(0);

        vm.expectRevert(Raffle.Raffle_OwnerCannotCallThisMethod.selector);
        raffle.pickWinner{value: pick_winner_fee}(0);

        vm.stopPrank();
        console.log("Reverts if the contract owner calls the pickWinner function.");

        vm.prank(s_player);
        // Case if a player with a position initiates pickWinner
        pick_winner_fee = raffle.getPickWinnerFee(0);
        uint no_of_players = raffle.getPlayerCount(0);
        assert( pick_winner_fee <= ((20 * s_entry_fee * no_of_players) / 100) );
        assert( pick_winner_fee >= ((4 * s_entry_fee * no_of_players) / 100) );
        // Case if someone without a position initiates pickWinner
        assert( raffle.getPickWinnerFee(0) == ((20 * s_entry_fee * no_of_players) / 100) );
        console.log("Pick winner fee is in between 20% and 4%");

        // Case of Winner retrieving the prizes
        checkPrizeDistribution(s_player);

        assertEq(address(s_player).balance, original_player_balance - raffle.getOwnersPool() );
        console.log("Finally picks a winner with a valid call to pickWinner function and pays all the positions.");

        assertEq(raffle.getPrizePool(0), 0);
        console.log("Prize pool is 0 again for the raffle.");
    }

    function testPickWinnerWithDifferentPlayers() public {
        uint no_of_players = 18;
        enterNPlayersToRaffle(no_of_players);

        uint player_count = raffle.getPlayerCount(0);

        assertEq(player_count, no_of_players);
        console.log("Entered %s players into the raffle.", no_of_players);

        assertEq(raffle.getPickWinnerFee(0), (20 * s_entry_fee * player_count) / 100);
        console.log("Pick winner fee for stranger is correct");

        // uint prize_pool = raffle.getPrizePool();

        console.log("Non Winner call the pickWinner function:");
        checkPrizeDistribution(s_player);

        uint additional_players = 23;

        enterNPlayersToRaffle(additional_players);

        assertEq(raffle.getPlayerCount(0), no_of_players + additional_players);
        console.log("Added additional %s players to the raffle.", additional_players);

        // ( address payable[POSITION_COUNT] memory positions, ) = raffle.getCurrentPositions();

        address player_3 = makeAddr("player_3"); // Player 3 gets the 9th position
        uint player_3_original_balance = player_3.balance;
        vm.prank(player_3);
        uint pick_winner_fee = raffle.getPickWinnerFee(0);
        uint prize_pool = raffle.getPrizePool(0);

        console.log("A Winner (player_3) calls the pickWinner function:");
        checkPrizeDistribution(player_3);

        assertEq(player_3_original_balance - pick_winner_fee + ((6 * prize_pool) / 100), player_3.balance);
        console.log("player_3 got 9th position and 6% of the prize pool after deducting the pick_winner_fee");
    }

    function enterRaffleMultipleByPlayer(uint count) internal {
        for(uint index = 0; index < count; index++) {
            enterRaffleByPlayer();
        }
    }

    function enterRaffleMultipleByMyPlayer(address player, uint count) internal {
        for(uint index = 0; index < count; index++) {
            enterRaffle(player, s_entry_fee);
        }
    }

    function enterNPlayersToRaffle(uint no_of_players) internal {
        for( uint index; index < no_of_players; index++ ) {
            enterRaffle(s_players[index], s_entry_fee);
        }
    }

    function checkPrizeDistribution(address caller) public {
        uint raffle_pool = raffle.getPrizePool(0);
        vm.startPrank(caller);
        uint pick_winner_fee = raffle.getPickWinnerFee(0);
        ( address payable[POSITION_COUNT] memory positions, uint[POSITION_COUNT] memory prizes ) = raffle.getCurrentPositions(0);

        vm.recordLogs();
        raffle.pickWinner{value: pick_winner_fee}(0);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        uint total_disbursed;
        bool emits_payment_success = false;

        for( uint index = 0; index < entries.length; index++ ) {
            bytes32 event_hash = keccak256("PaymentSuccess(address,uint256)");

            if( event_hash == entries[index].topics[0] ) {
                assertEq(uint(entries[index].topics[1]), uint160(address(positions[index])));
                uint prize = abi.decode(entries[index].data, (uint));
                assertEq(prize, prizes[index]);
                total_disbursed += prize;
                emits_payment_success = true;
            }

            if( keccak256("PickedWinners(address[10])") == entries[index].topics[0] ) {
                address[10] memory emitted_positions = abi.decode(entries[index].data, (address[10]));
                for( uint index_1; index_1 < positions.length; index_1++ ) {
                    assertEq(positions[index_1], emitted_positions[index_1]);
                }
                console.log('Emits Picked Winners event');
            }
        }

        if( emits_payment_success ) {
            console.log("Emits Payment Success events");
        } else {
            fail("Didn't emit payment success event");
        }

        console.log("Pool:", raffle_pool);

        console.log("Total Paid Out: %s", total_disbursed);

        console.log("Owner's Pool: %s", raffle.getOwnersPool());

        vm.stopPrank();
    }

    function testUnclaimedBalances() public {
        enterRaffleMultipleByMyPlayer(address(reverter), 10);

        assertEq(raffle.getPlayerCount(0), 10);
        assertEq(raffle.getPlayer(0, 0), address(reverter));
        console.log("Entered into raffle by reverting contract");

        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle_NoUnclaimedBalanceAvailable.selector, address(reverter))
        );
        vm.prank(address(reverter));
        raffle.withdrawUnclaimedBalance();
        console.log("Reverts when no unclaimed balance is available.");

        uint pick_winner_fee = raffle.getPickWinnerFee(0);
        uint prize_pool = raffle.getPrizePool(0);
        raffle.pickWinner{value: raffle.getPickWinnerFee(0)}(0);

        uint unclaimedBalance = raffle.getUnclaimedBalance(address(reverter));
        assert( unclaimedBalance > 0 );
        assertEq(unclaimedBalance + raffle.getOwnersPool(), prize_pool + pick_winner_fee);
        console.log("Unclaimed balance available for the reverter contract.");

        vm.prank(address(reverter));
        raffle.withdrawUnclaimedBalance();
        assertEq(raffle.getUnclaimedBalance(address(reverter)), unclaimedBalance);
        console.log("Unable to withdraw using withdrawUnclaimedBalance function because reverter never accepts a value.");

        address player_0 = makeAddr("player_0");
        uint player_0_starting_balance = player_0.balance;
        vm.prank(address(reverter));
        raffle.trnsferUnclaimedBalance(payable(player_0));
        assertEq(player_0_starting_balance + unclaimedBalance, player_0.balance);
        assertEq(raffle.getUnclaimedBalance(address(reverter)), 0);
        console.log("Transfers unclaimed funds to player_0.");

        enterRaffleMultipleByMyPlayer(address(reverter), 10);
        raffle.pickWinner{value: raffle.getPickWinnerFee(0)}(0);
        uint original_reverter_balance = address(reverter).balance;
        assertEq(raffle.getUnclaimedBalance(address(reverter)), unclaimedBalance);
        reverter.toggleReverting();
        vm.prank(address(reverter));
        raffle.withdrawUnclaimedBalance();
        assertEq(raffle.getUnclaimedBalance(address(reverter)), 0);
        assertEq(address(reverter).balance - original_reverter_balance, unclaimedBalance);
        console.log("Reverter is now able to withdraw the unclaimed balance after resetting the revert properties");
    }

    function testFallback() public {
        vm.startPrank(s_player);
        uint original_balance = s_player.balance;

        vm.expectRevert();
        (bool success, bytes memory data) = address(raffle).call{value: 200}("");
        assertEq(success, true);
        assertEq(abi.decode(data, (string)), "");
        assertEq(original_balance, s_player.balance);

        vm.expectRevert();
        bool rSuccess = payable(address(raffle)).send(200);
        assertEq(rSuccess, true);
        assertEq(original_balance, s_player.balance);
        vm.stopPrank();

        console.log("Raffle fallback successfully reverts with no data.");
    }

    // test for owner withdrawl
}