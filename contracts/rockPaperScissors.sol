// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract RPSGame is Ownable {



    // ~~~~~~~~ State ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    using SafeMath for uint;

    uint public BET_MIN = 1 wei;
    uint SECOND_PLAY_TIMEOUT = 1 minutes;
    uint FIRST_PLAY_TIMEOUT = 1 hours;

    bool matchCreationEnabled = true;

    function updateMatchCreationStatus(bool matchCreationMode) public onlyOwner {
        matchCreationEnabled = matchCreationMode;
    }

    mapping(uint => OpenMatch) betToOpenMatch;
    RPSMatch[] public matches;



    // ~~~~~~~~ Init ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    constructor() Ownable(){}



    // ~~~~~~~~ Events ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    event OpenedMatch(OpenMatch openMatch);
    event OpenMatchCanceled(uint value);
    event MatchCreated(uint index, address game);



    // ~~~~~~~~ Mods ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    modifier validBet() {
        require(msg.value >= BET_MIN, "Min bet is set to be at least 1 wei");
        _;
    }

    modifier canCreateMatch() {
        require(matchCreationEnabled, "Match creation disabled");
        _;
    }

    modifier isGameOwner(uint _value) {
        require(betToOpenMatch[_value].player1 == payable(msg.sender), "User is not the owner of the OpenGame");
        _;
    }



    // ~~~~~~~~ Functions ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    function newMatch() public payable validBet canCreateMatch {
        if (betToOpenMatch[msg.value].bet != 0) {
            OpenMatch memory openMatch = betToOpenMatch[msg.value];
            uint index = matches.length;
            RPSMatch newGame = new RPSMatch(index, openMatch.player1, payable(msg.sender), block.timestamp + FIRST_PLAY_TIMEOUT, SECOND_PLAY_TIMEOUT, msg.value);
            payable(address(newGame)).transfer(msg.value.add(openMatch.bet));
            matches.push(newGame);
            emit MatchCreated(index, address(newGame));
            delete betToOpenMatch[msg.value];
        }
        else {
            OpenMatch memory openMatch = OpenMatch(payable(msg.sender), msg.value);
            betToOpenMatch[msg.value] = openMatch;
            emit OpenedMatch(openMatch);
        }
    }

    function cancel(uint _value) public isGameOwner(_value) {
        OpenMatch memory om = betToOpenMatch[_value];
        om.player1.transfer(om.bet);
        delete betToOpenMatch[_value];
        emit OpenMatchCanceled(_value);
    }



    // ~~~~~~~~ Structs ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    struct OpenMatch {
        address payable player1;
        uint bet;
    }

}

contract RPSMatch {



    // ~~~~~~~~ State ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    uint public index;

    enum GameStatus {Active, Canceled, Finished}
    enum Move {None, Rock, Paper, Scissors}
    enum Outcome {None, Player1, Player2, Draw}
    mapping(Move => mapping(Move => Outcome)) resultHandler;

    address payable player1;
    address payable player2;
    uint bet;
    Outcome public outcome;
    Move public player1Move;
    Move public player2Move;
    bytes32 public player1EncryptedMove;
    bytes32 public player2EncryptedMove;
    uint afterPlayTimeout;
    uint currentTimeout;
    GameStatus public status;



    // ~~~~~~~~ Init ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    constructor(uint _index, address payable _player1, address payable _player2, uint _initialTimeout, uint _afterPlayTimeout, uint _bet){
        index = _index;
        player1 = _player1;
        player2 = _player2;
        currentTimeout = _initialTimeout;
        afterPlayTimeout = _afterPlayTimeout;
        bet = _bet;
        outcome = Outcome.None;
        status = GameStatus.Active;
        createHandler();
    }



    // ~~~~~~~~ Events ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    event Result(string outcome);
    event CanceledMatch();

    // ~~~~~~~~ Mods ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    modifier isPlayer() {
        require(msg.sender == player1 || msg.sender == player2, "You don't belong in this match");
        _;
    }

    modifier bothPlayed() {
        require(player1EncryptedMove.length != 0 && player2EncryptedMove.length != 0, "Both players must play before revealing");
        _;
    }

    modifier isMatchActive() {
        require(status == GameStatus.Active, "Game is no longer active");
        _;
    }



    // ~~~~~~~~ Transactions ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    function createHandler() private {
        resultHandler[Move.Rock][Move.Rock] = Outcome.Draw;
        resultHandler[Move.Rock][Move.Paper] = Outcome.Player2;
        resultHandler[Move.Rock][Move.Scissors] = Outcome.Player1;
        resultHandler[Move.Paper][Move.Rock] = Outcome.Player1;
        resultHandler[Move.Paper][Move.Paper] = Outcome.Draw;
        resultHandler[Move.Paper][Move.Scissors] = Outcome.Player2;
        resultHandler[Move.Scissors][Move.Rock] = Outcome.Player2;
        resultHandler[Move.Scissors][Move.Paper] = Outcome.Player1;
        resultHandler[Move.Scissors][Move.Scissors] = Outcome.Draw;
    }

    fallback() external payable {}

    receive() external payable {}

    function setPlay(bytes32 encryptedMove) public isPlayer isMatchActive {
        if (hasMatchTimedOut()) {
            cancelMatch();
            return;
        }
        if (msg.sender == player1) {
            player1EncryptedMove = encryptedMove;
        }
        else {
            player2EncryptedMove = encryptedMove;
        }
        currentTimeout = block.timestamp + afterPlayTimeout;
    }

    function commitPlay(string memory play, string memory salt, bytes32 encryptedPlay) public isPlayer isMatchActive bothPlayed {
        require(encryptedPlay == keccak256(abi.encodePacked(play, salt)), "Your encrypted play differs from the play you are trying yo commit");
        if (payable(msg.sender) == player1) {
            require(player1EncryptedMove == encryptedPlay, "Commits are not equal");
            require(player1Move == Move.None, "Player has already revealed move");
            bytes memory decodeMove = bytes(play);
            player1Move = parseMoveFromBytes(decodeMove);
        } else {
            require(player2EncryptedMove == encryptedPlay, "Commits are not equal");
            require(player2Move == Move.None, "Player has already revealed move");
            bytes memory decodeMove = bytes(play);
            player2Move = parseMoveFromBytes(decodeMove);
        }
        finishGame();
    }

    function parseMoveFromBytes(bytes memory _move) private pure returns (Move){
        if (_move[0] == 'r') {
            return Move.Rock;
        }
        if (_move[0] == 'p') {
            return Move.Paper;
        }
        if (_move[0] == 's') {
            return Move.Scissors;
        }
        return Move.None;
    }

    function bothPlayersCommitedTheirPlays() private returns(bool) {
        return player1Move != Move.None && player2Move != Move.None;
    }

    function finishGame() private {
        if(!bothPlayersCommitedTheirPlays()) return;

        outcome = resultHandler[player1Move][player2Move];

        if (outcome == Outcome.Player1) {
            player1.transfer(bet * 2);
            emit Result("Player 1 won!");
        }
        else if (outcome == Outcome.Player2) {
            player2.transfer(bet * 2);
            emit Result("Player 2 won!");
        }
        else if (outcome == Outcome.Draw) {
            player2.transfer(bet);
            player1.transfer(bet);
            emit Result("Ganamos, perdimos, igual nos divetimos!!!! :D");
        }
        status = GameStatus.Finished;
    }

    function hasMatchTimedOut() view private returns (bool){
        return block.timestamp >= currentTimeout;
    }

    function cancelMatch() private {
        player1.transfer(bet);
        player2.transfer(bet);
        status = GameStatus.Canceled;
        emit CanceledMatch();
    }

    // ~~~~~~~~ Structs ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    struct MoveData {
        Move move;
        bytes32 encryptedMove;
    }
}