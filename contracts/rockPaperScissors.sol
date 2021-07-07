// SPDX-License-Identifier: MIT
pragma solidity ^0.4.0;

contract RockPaperScissorsGame {

    address[] public instances;

    function count() public constant returns(unit count) {
        return instances.length;
    }

    function create() public returns(address instance) {
        RockPaperScissorsInstance instance = new RockPaperScissorsInstance();
        instances.push(instance);
        return instance;
    }
}

contract RockPaperScissorsInstance {

    uint public stake = 1 wei;

    enum Plays { Rock, Paper, Scissors, None }
    enum Results { None, Player1, Player2, Draw }
    enum Players { Player1, Player2 }

    mapping(Plays => mapping(Plays => Results)) possibleResults;
    mapping(Players => address payable) players;
    mapping(Players => Plays) plays;
    mapping(string => Plays) stringToPlay;

    event MatchIsReady(uint readyMatchId, address payable player1, address payable player2);
    event Result(Results outcome, address payable player1, address payable player2);



    constructor() {
        possibleResults[Plays.Rock][Plays.Rock] = Results.Draw;
        possibleResults[Plays.Rock][Plays.Paper] = Results.Player2;
        possibleResults[Plays.Rock][Plays.Scissors] = Results.Player1;
        possibleResults[Plays.Paper][Plays.Rock] = Results.Player1;
        possibleResults[Plays.Paper][Plays.Paper] = Results.Draw;
        possibleResults[Plays.Paper][Plays.Scissors] = Results.Player2;
        possibleResults[Plays.Scissors][Plays.Rock] = Results.Player2;
        possibleResults[Plays.Scissors][Plays.Paper] = Results.Player1;
        possibleResults[Plays.Scissors][Plays.Scissors] = Results.Draw;

        plays[Players.Player1] = Plays.None;
        plays[Players.Player2] = Plays.None;

        stringToPlay["R"] = Plays.Rock;
        stringToPlay["P"] = Plays.Paper;
        stringToPlay["S"] = Plays.Scissors;
    }

    // Modifiers ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    modifier isPlayer() {
        require(msg.sender == players[Players.Player1] || msg.sender == players[Players.Player2],
            "You are not playing this game."
        );
        _;
    }

    modifier isValidChoice(string memory _playerChoice) {
        require(keccak256(bytes(_playerChoice)) == keccak256(bytes('R')) ||
        keccak256(bytes(_playerChoice)) == keccak256(bytes('P')) ||
            keccak256(bytes(_playerChoice)) == keccak256(bytes('S')) ,
            "Your choice is not valid, it should be one of R, P and S."
        );
        _;
    }

    modifier playersMadeChoice() {
        require(plays[Players.Player1] != address(0) && plays[Players.Player2] != address(0),
            "The player(s) have not made their choice yet."
        );
        _;
    }

    // Functions ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    function validatePlayer(address add, Players player) {
        return players[player] == add;
    }

    function hasPlayed(Players player) {
        return plays[player] != Plays.None;
    }

    function join() external payable
    {
        if (Players.Player1 == address(0)) {
            Players.Player1 = msg.sender;
        } else
            Players.Player2 = msg.sender;
    }

    function play(string calldata _playerChoice) external
    isPlayer()
    isValidChoice(_playerChoice)
    {
        if (validatePlayer(msg.sender, Players.Player1) && !hasPlayed(Players.Player1)) {
            plays[Players.Player1] = _playerChoice;
        } else if (validatePlayer(msg.sender, Players.Player2) && !hasPlayed(Players.Player2)) {
            plays[Players.Player2] = _playerChoice;
        }
    }

    function disclose() external
    isPlayer()
    playersMadeChoice()
    {
        Plays player1Play = plays[Players.Player1];
        Plays player2Play = plays[Players.Player2];
        int result = possibleResults[player1Play][player2Play];

        if (result == Results.Draw) {
            player1.transfer(stake);
            player2.transfer(stake);
        } else if (result == Results.Player1) {
            player1.transfer(address(this).balance);
        } else if (result == Results.Player2) {
            player2.transfer(address(this).balance);
        }
    }


}