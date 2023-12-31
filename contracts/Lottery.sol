// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.19;

import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";

error Raffle__NotEnoughETH();
error Raffle__NotOpen();
error Raffle__transactionFailed();
error Raffle__UpKeepNotMet(uint256 balance, uint256 players, uint256 RaffleState);

contract Raffle is VRFConsumerBaseV2, AutomationCompatibleInterface {
    //State variables
    uint256 private s_entranceFee;
    address payable[] private s_players;
    RaffleState private s_raffleState;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_keyHash;
    uint64 private s_subscriptionId;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private s_callbackGasLimit;
    uint32 private constant NUM_WORDS = 1;
    address private s_recentWinner;
    uint256 private s_lastTimeStamp;
    uint256 private immutable i_interval;

    //Events
    event Players(address indexed players);
    event RequestRaffleWinner(uint256 indexed requestId);
    event WinnerPicked(address indexed winner);

    enum RaffleState {
        OPEN,
        CALCULATING
    }

    constructor(
        uint256 entranceFee,
        address vrfCoordinator,
        bytes32 keyHash,
        uint64 subscriptionId,
        uint32 callbackGasLimit,
        uint256 interval
    ) VRFConsumerBaseV2(vrfCoordinator) {
        s_entranceFee = entranceFee;
        s_raffleState = RaffleState.OPEN;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_keyHash = keyHash;
        s_subscriptionId = subscriptionId;
        s_callbackGasLimit = callbackGasLimit;
        s_lastTimeStamp = block.timestamp;
        i_interval = interval;
    }

    function enterRaffle() public payable {
        if (msg.value < s_entranceFee) {
            revert Raffle__NotEnoughETH();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__NotOpen();
        }
        s_players.push(payable(msg.sender));
        emit Players(msg.sender);
    }

    function checkUpkeep(
        bytes memory /* checkData */
    ) public view override returns (bool upkeepNeeded, bytes memory /* performData */) {
        bool isOpen = (s_raffleState == RaffleState.OPEN);
        bool hasPlayers = (s_players.length > 0);
        bool hasBalance = s_entranceFee > 0;
        bool timePassed = (block.timestamp - s_lastTimeStamp) > i_interval;
        upkeepNeeded = (isOpen && hasBalance && hasPlayers && timePassed);
        return (upkeepNeeded, "");
    }

    //Getting the Random winner
    function performUpkeep(bytes calldata /* performData */) external override {
        (bool upKeepNeeded, ) = checkUpkeep("");
        if (!upKeepNeeded) {
            revert Raffle__UpKeepNotMet(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }
        s_raffleState = RaffleState.CALCULATING;
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_keyHash,
            s_subscriptionId,
            REQUEST_CONFIRMATIONS,
            s_callbackGasLimit,
            NUM_WORDS
        );
        emit RequestRaffleWinner(requestId);
    }

    function fulfillRandomWords(
        uint256 /*requestId*/,
        uint256[] memory randomWords
    ) internal override {
        uint256 indexWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexWinner];
        s_recentWinner = recentWinner;
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__transactionFailed();
        }
        emit WinnerPicked(recentWinner);
    }

    function getFee() public view returns (uint256) {
        return s_entranceFee;
    }

    function getRaffleState() public view returns (RaffleState) {
        return s_raffleState;
    }

    function getNumWords() public pure returns (uint256) {
        return NUM_WORDS;
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getNumPlayers() public view returns (uint256) {
        return s_players.length;
    }

    function getLatestTimeStanp() public view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getRequestConf() public pure returns (uint256) {
        return REQUEST_CONFIRMATIONS;
    }
}
