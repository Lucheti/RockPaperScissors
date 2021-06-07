pragma solidity ^0.5.0;

contract RockPaperScissors {
    address payable private player1;
    address payable private player2;
    string private choiceOfPlayer1;
    string private choiceOfPlayer2;
    bool private hasPlayer1MadeChoice;
    bool private hasPlayer2MadeChoice;

    uint256 public stake;
    mapping(string => mapping(string => uint8)) private states;

    constructor() public {
        states['R']['R'] = 0;
        states['R']['P'] = 2;
        states['R']['S'] = 1;
        states['P']['R'] = 1;
        states['P']['P'] = 0;
        states['P']['S'] = 2;
        states['S']['R'] = 2;
        states['S']['P'] = 1;
        states['S']['S'] = 0;

        stake = 1 ether;
    }
    
    // Modifiers ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    
    modifier isPlayer() {
        require(msg.sender == player1 || msg.sender == player2,
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
        require(hasPlayer1MadeChoice && hasPlayer2MadeChoice,
                "The player(s) have not made their choice yet."
        );
        _;
    }

    // Functions ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
     
    function join() external payable 
    {
        if (player1 == address(0)) {
            player1 = msg.sender;
            stake = msg.value;
            
        } else
            player2 = msg.sender;
    }
    
    function makeChoice(string calldata _playerChoice) external 
        isPlayer()                      
        isValidChoice(_playerChoice)
    {
        if (msg.sender == player1 && !hasPlayer1MadeChoice) {
            choiceOfPlayer1 = _playerChoice;
            hasPlayer1MadeChoice = true;
        } else if (msg.sender == player2 && !hasPlayer2MadeChoice) {
            choiceOfPlayer2 = _playerChoice;
            hasPlayer2MadeChoice = true;
        }
    }
    
    function disclose() external 
        isPlayer()          
        playersMadeChoice()
    {
        int result = states[choiceOfPlayer1][choiceOfPlayer2];
        if (result == 0) {
            player1.transfer(stake); 
            player2.transfer(stake);
        } else if (result == 1) {
            player1.transfer(address(this).balance);
        } else if (result == 2) {
            player2.transfer(address(this).balance);
        }
        
        player1 = address(0);
        player2 = address(0);

        choiceOfPlayer1 = "";
        choiceOfPlayer2 = "";
        
        hasPlayer1MadeChoice = false;
        hasPlayer2MadeChoice = false;
        
        stake = 1 ether;
    }
}