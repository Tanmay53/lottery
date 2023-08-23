// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;


/**
 * @title A Lottery contract
 * @author Tanmay Khatri
 * @notice This is contract for creating a lottery
 * @dev Implements Chainlink VRFv2
 */
contract Raffle {
    error Raffle_NotEnoughEthSent();
    error Raffle_NotEnoughPlayers(uint raffle_id);
    error Raffle_NoUnclaimedBalanceAvailable(address withdrawer);
    error Raffle_OwnerCannotCallThisMethod();
    error Raffle_OnlyOwnerCanCallThisMethod();

    uint constant public MIN_PLAYERS = 10;
    uint constant private POSITION_COUNT = 10;
    uint[POSITION_COUNT] private PRIZES = [ // Percentage of the prize pool as the prize. total 100% prize distribution
        20,
        15,
        10,
        9,
        9,
        9,
        8,
        8,
        6,
        5
    ];
    uint constant private BASE_PICK_WINNER_FEE = 4; // Min Percentage of prize pool taken as fee
    uint constant private MAX_PICK_WINNER_FEE = 20; // Max Percentage of prize pool taken as fee

    uint private immutable i_entrance_fee;
    address private immutable i_owner;

    mapping(uint => address payable[]) private s_raffle_id_to_players;
    uint private s_owners_pool;
    address payable[] private s_owners_raffle_players;
    mapping(uint => uint) private s_raffle_id_to_redeemed_pool;
    mapping(address => uint) private s_unclaimed_balances;
    uint private s_raffle_count;

    event EnteredRaffle(uint indexed raffle_id, address indexed player);
    event PickedWinners(uint indexed raffle_id, address payable[POSITION_COUNT] positions, uint prize_pool);
    event PaymentSuccess(address indexed payee, uint value);
    event PickedWinnersForOwnersRaffle(address payable[POSITION_COUNT] positions, uint prize_pool);

    modifier minimumPlayers(uint raffleId) {
        if( (s_raffle_id_to_players[raffleId].length < MIN_PLAYERS)
            || (getPrizePool(raffleId) < (i_entrance_fee * POSITION_COUNT))
        ) {
            revert Raffle_NotEnoughPlayers(raffleId);
        }
        _;
    }

    modifier returnExtraEth(uint refunds) {
        _;
        if( refunds > 0 ) {
            payWithCaution(payable(msg.sender), refunds);
        }
    }

    modifier checkFee(uint fee) {
        if( msg.value < fee ) {
            revert Raffle_NotEnoughEthSent();
        }
        _;
    }

    modifier notOwner() {
        if( msg.sender == i_owner ) {
            revert Raffle_OwnerCannotCallThisMethod();
        }
        _;
    }

    modifier onlyOwner() {
        if( msg.sender != i_owner ) {
            revert Raffle_OnlyOwnerCanCallThisMethod();
        }
        _;
    }

    modifier safeDeductUnclaimedBalance() {
        uint balance = s_unclaimed_balances[msg.sender];
        if( balance == 0 ) {
            revert Raffle_NoUnclaimedBalanceAvailable(msg.sender);
        }

        _;

        s_unclaimed_balances[msg.sender] -= balance;
    }

    constructor(uint entrace_fee) {
        i_entrance_fee = entrace_fee;
        i_owner = msg.sender;
        s_raffle_id_to_players[0] = new address payable[](0);
        s_raffle_id_to_redeemed_pool[0] = 0;
        s_raffle_count = 1;
    }

    function getEntranceFee() external view returns(uint) {
        return i_entrance_fee;
    }

    function getUnclaimedBalance(address player) external view returns(uint) {
        return s_unclaimed_balances[player];
    }

    function getPlayer(uint raffleId, uint index) external view returns(address) {
        return s_raffle_id_to_players[raffleId][index];
    }

    function getOwner() external view returns(address) {
        return i_owner;
    }

    function getRedeemedPool(uint raffleId) external view returns(uint) {
        return s_raffle_id_to_redeemed_pool[raffleId];
    }

    function getOwnersPool() external view returns(uint) {
        return s_owners_pool;
    }

    function getPlayerCount(uint raffleId) external view returns(uint) {
        return s_raffle_id_to_players[raffleId].length;
    }

    function getRaffleCount() external view returns(uint) {
        return s_raffle_count;
    }

    function getCurrentPositions(uint raffleId) minimumPlayers(raffleId) external view returns(address payable[POSITION_COUNT] memory positions, uint[POSITION_COUNT] memory prizes) {
        positions = getPositions(s_raffle_id_to_players[raffleId]);
        uint prize_pool = getPrizePool(raffleId);

        for( uint index; index < POSITION_COUNT; index++ ) {
            prizes[index] = (PRIZES[index] * prize_pool) / 100;
        }
    }

    function startNewRaffle() external payable {
        s_raffle_id_to_players[s_raffle_count] = new address payable[](0);
        s_raffle_id_to_redeemed_pool[s_raffle_count] = 0;
        s_raffle_count++;

        enterRaffle(s_raffle_count - 1);
    }

    function enterRaffleAndPickWinner(uint raffleId, uint no_of_entries) external payable
        checkFee((i_entrance_fee * no_of_entries) + getEnterRaffleAndPickWinnerFee(raffleId, no_of_entries))
    {
        pushSenderToRaffle(raffleId, (msg.value - getPickWinnerFee(raffleId)) / i_entrance_fee);

        uint pickWinnerFee = getPickWinnerFee(raffleId);
        uint refunds = msg.value - (i_entrance_fee * no_of_entries) - pickWinnerFee;

        distributePoolToWinners(raffleId, pickWinnerFee);

        if( refunds > 0 ) {
            payWithCaution(payable(msg.sender), refunds);
        }
    }

    function pickWinner(uint raffleId) external payable
        checkFee(getPickWinnerFee(raffleId))
        returnExtraEth(msg.value - getPickWinnerFee(raffleId))
    {
        distributePoolToWinners(raffleId, getPickWinnerFee(raffleId));
    }

    function withdrawUnclaimedBalance() external safeDeductUnclaimedBalance {
        payWithCaution(payable(msg.sender), s_unclaimed_balances[msg.sender]);
    }

    function trnsferUnclaimedBalance(address payable to) external safeDeductUnclaimedBalance {
        payWithCaution(to, s_unclaimed_balances[msg.sender]);
    }

    function withdrawOwnersPool() external onlyOwner {
        uint distribution_pool = s_owners_pool / 2;

        address payable[POSITION_COUNT] memory positions = getPositions(s_owners_raffle_players);

        payAllPositions(positions, distribution_pool);

        emit PickedWinnersForOwnersRaffle(positions, distribution_pool);

        payWithCaution(payable(i_owner), s_owners_pool - distribution_pool);

        // Reset variables
        s_owners_pool = 0;
    }

    function enterRaffle(uint raffleId) public payable
        checkFee(i_entrance_fee)
        returnExtraEth(msg.value % i_entrance_fee)
    {
        pushSenderToRaffle(raffleId, msg.value / i_entrance_fee);
    }

    function getPickWinnerFee(uint raffleId) public view returns(uint) {
        uint prize_pool = getPrizePool(raffleId);

        uint minimum_fee = (prize_pool * BASE_PICK_WINNER_FEE) / 100; // BASE_PICK_WINNER_FEE% of the prize pool

        uint position_based_prize_component;

        address payable[POSITION_COUNT] memory positions = getPositions(s_raffle_id_to_players[raffleId]);
        bool callerIsAWinner = false;

        // This is to prevent users from trying to take multiple positions
        for( uint index; index < POSITION_COUNT; index++ ) {
            bool position_check = msg.sender == positions[index];
            if( position_check ) {
                position_based_prize_component += PRIZES[index];
            }
            callerIsAWinner = callerIsAWinner || position_check;
        }

        if( !callerIsAWinner ) {
            return (MAX_PICK_WINNER_FEE * prize_pool) / 100; // MAX_PICK_WINNER_FEE% of the prize pool
        }

        uint position_based_fee = (MAX_PICK_WINNER_FEE * position_based_prize_component * prize_pool) / 1e4; // MAX_PICK_WINNER_FEE% of PRIZE% of prize_pool

        return minimum_fee > position_based_fee
            ? minimum_fee
            : position_based_fee;
    }

    function getPrizePool(uint raffleId) public view returns(uint) {
        return (i_entrance_fee * s_raffle_id_to_players[raffleId].length) - s_raffle_id_to_redeemed_pool[raffleId];
    }

    function getMaxPickWinnerFee(uint raffleId) public view returns(uint) {
        return (MAX_PICK_WINNER_FEE * getPrizePool(raffleId)) / 100;
    }

    function getEnterRaffleAndPickWinnerFee(uint raffleId, uint no_of_entries) public view returns(uint) {
        return (MAX_PICK_WINNER_FEE * ( getPrizePool(raffleId) + (i_entrance_fee * no_of_entries) )) / 100;
    }

    function pushSenderToRaffle(uint raffleId, uint no_of_entries) internal {
        address payable player = payable(msg.sender);

        for( uint index = 0; index < no_of_entries; index++ ) {
            s_raffle_id_to_players[raffleId].push(player);
            s_owners_raffle_players.push(player);
        }

        emit EnteredRaffle(raffleId, msg.sender);
    }

    function distributePoolToWinners(uint raffleId, uint pickWinnerFee) internal
        minimumPlayers(raffleId)
        notOwner
    {
        uint prize_pool = getPrizePool(raffleId);

        address payable[POSITION_COUNT] memory positions = getPositions(s_raffle_id_to_players[raffleId]);

        payAllPositions(positions, prize_pool);

        emit PickedWinners(raffleId, positions, prize_pool);

        s_owners_pool += pickWinnerFee;

        // At end, reset raffle parameters
        s_raffle_id_to_redeemed_pool[raffleId] += prize_pool;
    }

    // Get uint version of the specified player
    function getPlayerAdrressInUint(address payable player) internal pure returns(uint) {
        return uint(uint160(address(player)));
    }

    // Get an array of players as per their position in raffle using the random number supplied,
    // divinding the random number by no_of_players and using it as the index for the winner.
    function getPositions(address payable[] memory players) internal pure returns(address payable[POSITION_COUNT] memory positions) {
        uint no_of_players = players.length;

        // Fetching players at 25%, 50% and 75%
        // Converting their address to uint256
        // Adding the three numbers
        uint random_no = getPlayerAdrressInUint(players[no_of_players / 2]) + getPlayerAdrressInUint(players[no_of_players / 4]) + getPlayerAdrressInUint(players[no_of_players * 3 / 4]);
        uint l_random_no = random_no; // Local random number

        for(uint index; index < POSITION_COUNT; index++) {
            positions[index] = players[l_random_no % no_of_players];

            l_random_no /= no_of_players;

            if( l_random_no == 0 ) {
                l_random_no = random_no;
            }
        }
    }

    // Pay the receiver and if the transaction fails keep the value in unclaimed balances for the receiver
    function payWithCaution(address payable receiver, uint value) internal {
        ( bool sent, ) = receiver.call{ value: value }("");
        if( !sent ) {
            s_unclaimed_balances[receiver] += value;
        }
        else {
            emit PaymentSuccess(receiver, value);
        }
    }

    function payAllPositions(address payable[POSITION_COUNT] memory positions, uint prize_pool) internal {
        uint distributions;

        for(uint index; index < POSITION_COUNT; index++) {
            uint prize = (prize_pool * PRIZES[index]) / 100;
            distributions += prize;
            payWithCaution(positions[index], prize);
        }

        // Check for remaing marginal pool left due to divisional remainders
        if( distributions < prize_pool ) {
            s_owners_pool += (prize_pool - distributions);
        }
    }

    /**
     * Todo:
     * * Make pickwinner function payable and take 4% as retrieval fee : Done
     * * Make a function to participate in raffle and pickWinner at the same time : Done
     * * Charge the platform fee of 4% of prize pool from the player which calls the pickWinner function : Done
     * * Ability to participate multiple times at once in a raffle. : Done
     * * Ability to start a new raffle. : Done
     * * Ability to retrive unclaimed balances by the owners. : Done
     * * Prevent one user from taking it all. : Done
     * * * There can be a case where a player tries to sabotage and invest heavily to gain all the positions in the raffle.
     * * * In this way the sabotager will get access to the funds raffled by the initial minimum players
     * To Prevent this, if one player gets more than one position, then the pickWinner charges increase by 20% of prize won in each position. : Done
     * * "Change the Owner" function for unclaimed balances. : Done
     * * Whenever the owner of the contract withdraws his funds, he has to share 50% of the earnings with current active players,
     * the winners will again be decided based on the getPositions function : Done
     * in this raffle one player can enter once only. : Not feasible
     * * Check remainig pool balance and shift it to the owner withdrawl balance : Done
     * * The contract owner never picks the winners : Done
     * * Fon non winninig players who pickWinner, the charge has been fixed to 20% of the pool. : Done
     * * fallback and receive function
     * * function to sunset the contract
     */
}