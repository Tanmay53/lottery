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

    address payable[] public s_players;
    RaffleState private s_raffle_state = RaffleState.OPEN;

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

    constructor(uint entrace_fee) {
        i_entrance_fee = entrace_fee;
    }

    function enterRaffle() external payable raffleIs(RaffleState.OPEN) {
        if( msg.value < i_entrance_fee ) {
            revert Raffle_NotEnoughEthSent();
        }

        s_players.push(payable(msg.sender));

        emit EnteredRaffle(msg.sender);
    }

    function pickWinner() external minimumPlayers raffleIs(RaffleState.OPEN) returns(address payable[] memory) {
        s_raffle_state = RaffleState.CALCULATING;

        uint no_of_players = s_players.length;

        // Fetching players at 25%, 50% and 75%
        // Converting their address to uint256
        // Adding the three number
        uint random_no = getPlayerAdrressUint(no_of_players / 2) + getPlayerAdrressUint(no_of_players / 4) + getPlayerAdrressUint(no_of_players * 3 / 4);

        address payable[] memory positions = getPositions(random_no, no_of_players);

        // At end, reset raffle parameters
        s_players = new address payable[](0);
        s_raffle_state = RaffleState.OPEN;

        return positions;
    }

    // Get uint version of the specified player
    function getPlayerAdrressUint(uint index) public view returns(uint) {
        return uint(uint160(address(s_players[index])));
    }

    // Get an array of players as per their position in raffle using the random number supplied,
    // divinding the random number by no_of_players and using it as the index for the winner.
    function getPositions(uint random_no, uint no_of_players) private view returns(address payable[] memory positions) {
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

    function getEntranceFee() public view returns(uint) {
        return i_entrance_fee;
    }


    /**
     * Todo:
     * * Pay the winners
     * * Make pickwinner function payable and take 4% as retrieval fee
     * * Make a function to participate in raffle and pickWinner at the same time
     * * Charge the platform fee of 4% of prize pool from the player which calls the pickWinner function
     * * 
     */
}