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

    // struct Positions {
    //     address payable[POSITION_COUNT] positions;
    // }

    uint constant public MIN_PLAYERS = 10;
    uint constant private POSITION_COUNT = 10;
    uint[POSITION_COUNT] private PRIZES = [ // Percentage of the prize pool as the prize
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
    uint constant private PICK_WINNER_FEE = 4; // Percentage of prize pool taken as fee

    uint private immutable i_entrance_fee;
    address private immutable i_owner;

    address payable[] private s_players;
    RaffleState private s_raffle_state = RaffleState.OPEN;

    mapping(address => uint) private s_unclaimed_balances;

    event EnteredRaffle(address indexed player);
    event PickedWinners(address payable[POSITION_COUNT] positions);

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

    modifier returnExtraEth(uint refunds) {
        _;
        if( msg.value > i_entrance_fee ) {
            payWithCaution(msg.sender, refunds);
        }
    }

    modifier checkFee(uint fee) {
        if( msg.value < fee ) {
            revert Raffle_NotEnoughEthSent();
        }
        _;
    }

    constructor(uint entrace_fee) {
        i_entrance_fee = entrace_fee;
        i_owner = msg.sender;
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

    function getOwner() external view returns(address) {
        return i_owner;
    }

    function enterRaffle() external payable
        checkFee(i_entrance_fee)
        raffleIs(RaffleState.OPEN)
        returnExtraEth(msg.value % i_entrance_fee)
    {
        uint no_of_entries = msg.value / i_entrance_fee;

        for( uint index = 0; index < no_of_entries; index++ ) {
            s_players.push(payable(msg.sender));
        }

        emit EnteredRaffle(msg.sender);
    }

    function pickWinner() external payable
        checkFee(getPickWinnerFee())
        minimumPlayers
        raffleIs(RaffleState.OPEN)
        returnExtraEth(msg.value - getPickWinnerFee())
    {
        s_raffle_state = RaffleState.CALCULATING;

        uint no_of_players = s_players.length;

        // Fetching players at 25%, 50% and 75%
        // Converting their address to uint256
        // Adding the three numbers
        uint random_no = getPlayerAdrressInUint(no_of_players / 2) + getPlayerAdrressInUint(no_of_players / 4) + getPlayerAdrressInUint(no_of_players * 3 / 4);

        address payable[POSITION_COUNT] memory positions = getPositions(random_no, no_of_players);

        payAllPositions(positions, getPrizePool());

        emit PickedWinners(positions);

        // At end, reset raffle parameters
        s_players = new address payable[](0);
        s_raffle_state = RaffleState.OPEN;
    }

    function getPickWinnerFee() public view returns(uint) {
        return (getPrizePool() * PICK_WINNER_FEE) / 100; // PICK_WINNER_FEE% of the prize pool
    }

    function getPrizePool() public view returns(uint) {
        return i_entrance_fee * s_players.length;
    }

    // Get uint version of the specified player
    function getPlayerAdrressInUint(uint index) internal view returns(uint) {
        return uint(uint160(address(s_players[index])));
    }

    // Get an array of players as per their position in raffle using the random number supplied,
    // divinding the random number by no_of_players and using it as the index for the winner.
    function getPositions(uint random_no, uint no_of_players) internal view returns(address payable[POSITION_COUNT] memory positions) {
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

    function payAllPositions(address payable[POSITION_COUNT] memory positions, uint prize_pool) internal {
        for(uint index; index < POSITION_COUNT; index++) {
            payWithCaution(positions[index], (prize_pool * PRIZES[index]) / 100 );
        }
    }

    /**
     * Todo:
     * * Make pickwinner function payable and take 4% as retrieval fee : Done
     * * Make a function to participate in raffle and pickWinner at the same time
     * * Charge the platform fee of 4% of prize pool from the player which calls the pickWinner function : Done
     * * Ability to participate multiple times at once in a raffle.
     * * Ability to start a new raffle.
     * * Ability to retrive unclaimed balances by the owners.
     * * Prevent one user from taking it all.
     * * * There can be a case where a player tries to sabotage and invest heavily to gain all the positions in the raffle.
     * * * In this way the sabotager will get access to the funds raffled by the initial minimum players
     * To Prevent this, if one player gets more than one position, then the pickWinner charges increase by 20% of prize won in each position.
     * * "Change the Owner" function for unclaimed balances.
     * * Whenever the owner of the contract withdraws his funds, he has to share 50% of the earnings with current active players,
     * the winners will again be decided based on the getPositions function
     * in this raffle one player can enter once only.
     */
}