// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import { console } from "forge-std/Test.sol";

/**
 * @title A Lottery contract
 * @author Tanmay Khatri
 * @notice This is contract for creating a lottery
 * @dev Implements Chainlink VRFv2
 */
contract Raffle {
    error Raffle_NotEnoughEthSent();
    error Raffle_NotEnoughPlayers();
    error Raffle_StateMismatch();

    enum RaffleState {
        OPEN,
        CALCULATING
    }

    uint constant public MIN_PLAYERS = 10;
    uint constant private POSITION_COUNT = 10;
    uint[] private PRIZES = [
        20,
        15,
        10,
        8,
        8,
        8,
        8,
        8,
        8,
        8
    ];

    uint private immutable i_entrance_fee;

    address payable[] private s_players;
    RaffleState private s_raffle_state = RaffleState.OPEN;

    mapping(address => uint) private s_unclaimed_balances;

    event EnteredRaffle(address indexed player);

    modifier minimumPlayers() {
        if( s_players.length < MIN_PLAYERS && address(this).balance > 0 ) {
            revert Raffle_NotEnoughPlayers();
        }
        _;
    }

    modifier raffleIs(RaffleState raffleState) {
        if( raffleState != s_raffle_state ) {
            revert Raffle_StateMismatch();
        }
        _;
    }

    modifier returnExtraEth() {
        _;
        if( msg.value > i_entrance_fee ) {
            payWithCaution(msg.sender, msg.value - i_entrance_fee);
        }
    }

    modifier checkEntranceFee() {
        if( msg.value < i_entrance_fee ) {
            revert Raffle_NotEnoughEthSent();
        }
        _;
    }

    constructor(uint entrace_fee) {
        i_entrance_fee = entrace_fee;
    }

    function getEntranceFee() external view returns(uint) {
        return i_entrance_fee;
    }

    function getRaffleState() external view returns(RaffleState) {
        return s_raffle_state;
    }

    function getUnclaimedBalance(address player) external view returns(uint) {
        return s_unclaimed_balances[player];
    }

    function getPlayer(uint index) external view returns(address) {
        return s_players[index];
    }

    function enterRaffle() external payable checkEntranceFee raffleIs(RaffleState.OPEN) returnExtraEth {
        s_players.push(payable(msg.sender));

        emit EnteredRaffle(msg.sender);
    }

    function pickWinner() external minimumPlayers raffleIs(RaffleState.OPEN) {
        s_raffle_state = RaffleState.CALCULATING;

        uint no_of_players = s_players.length;

        // Fetching players at 25%, 50% and 75%
        // Converting their address to uint256
        // Adding the three number
        uint random_no = getPlayerAdrressInUint(no_of_players / 2) + getPlayerAdrressInUint(no_of_players / 4) + getPlayerAdrressInUint(no_of_players * 3 / 4);

        payAllPositions(getPositions(random_no, no_of_players), (no_of_players * i_entrance_fee));

        // At end, reset raffle parameters
        s_players = new address payable[](0);
        s_raffle_state = RaffleState.OPEN;
    }

    // Get uint version of the specified player
    function getPlayerAdrressInUint(uint index) internal view returns(uint) {
        return uint(uint160(address(s_players[index])));
    }

    // Get an array of players as per their position in raffle using the random number supplied,
    // divinding the random number by no_of_players and using it as the index for the winner.
    function getPositions(uint random_no, uint no_of_players) internal view returns(address payable[] memory positions) {
        positions = new address payable[](POSITION_COUNT);
        uint l_random_no = random_no; // Local random number

        for(uint index; index < POSITION_COUNT; index++) {
            positions[index] = s_players[l_random_no % no_of_players];

            l_random_no /= no_of_players;

            if( l_random_no == 0 ) {
                l_random_no = random_no;
            }
        }
    }

    // Pay the receiver and if the transaction fails keep the value in unclaimed balances for the receiver
    function payWithCaution(address receiver, uint value) internal {
        ( bool sent, ) = payable(receiver).call{ value: value }("");
        if( !sent ) {
            s_unclaimed_balances[receiver] += value;
        }
    }

    function payAllPositions(address payable[] memory positions, uint prize_pool) internal {
        for(uint index; index < POSITION_COUNT; index++) {
            payWithCaution(positions[index], (prize_pool * PRIZES[index]) / 100 );
        }
    }

    /**
     * Todo:
     * * Pay the winners
     * * Make pickwinner function payable and take 4% as retrieval fee
     * * Make a function to participate in raffle and pickWinner at the same time
     * * Charge the platform fee of 4% of prize pool from the player which calls the pickWinner function
     * * Ability to participate multiple times at once in a raffle.
     */
}