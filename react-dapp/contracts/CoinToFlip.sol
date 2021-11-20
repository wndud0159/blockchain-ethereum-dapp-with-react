pragma solidity ^0.4.24; // versin pragma

contract CoinToFlip {
    uint constant MAX_CASE = 2;
    uint constant MIN_BET = 0.01 ether; // 이더라는 타입이 있기 때문에 정수형타입이여도 가능 
    uint constant MAX_BET = 10 ether;
    uint constant HOUSE_FEE_PERCENT = 5;
    uint constant HOUSE_MIN_FEE = 0.005 ether;

    address public owner;
    uint public lockedInBets;

    struct Bet {
        uint amount;
        uint8 numOfBetBit;
        uint placeBlockNumber; // block number of bet tx
        // bit mask representing winning bet outcomes
        // 0000 0010 for front side of coin, 50% chance
        // 0000 0001 for back side of coin, 50% chance
        // 0000 0011 for both sides, 100% chance - no reward
        uint8 mask;
        address gambler; // address of a gambler, used to pat out winning bets

    }

    mapping (address => Bet) bets; //Bet book

    event Reveal(uint reveal);
    event Payment(address indexed beneficiary, uint amount);
    event FailedPayment(address indexed beneficiary, uint amount);

    constructor() public {
        owner = msg.sender;
    }

    // Standard modifier on methods invokable only my contract owner.
    modifier onlyOwner {
        require (msg.sender == owner, "Only owner can call this function.");
        _;
    }

    function withdrawFunds(address beneficiary, uint withdrawAmount) external onlyOwner {
        require (withdrawAmount + lockedInBets <= address(this).balance, "larger than balance.");
        sendFunds(beneficiary, withdrawAmount);
    }

    function sendFunds(address beneficiary, uint amount) private {
        if(beneficiary.send(amount)) {
            emit Payment(beneficiary, amount);
        } else {
            emit FailedPayment(beneficiary, amount);
        }
    }

    function kill() external onlyOwner {
        require (lockedInBets == 0, "All bets should be preocessed before self-destruct.");
        selfdestruct(owner);
    }

    function () public payable {}

    //Bet by player
    function placeBet(uint8 betMask) external payable {
        uint amount = msg.value;

        require (amount >= MIN_BET && amount <= MAX_BET, "Amount is out of range");
        require (betMask > 0 && betMask < 256, "Mask should be 0 bit");

        Bet storage bet = bets[msg.sender]; // mapping bets(address => Bet)
        //Bet bet = bets[msg.sender];

        require (bet.gambler == address(0), "Bet should be empty state"); // can be place a bet
        // if(bet.gambler == null) x

        //count bet bit in the betMask
        //0000 0011 number of bits = 2
        //0000 0001 number of bits = 1
        uint8 numOfBetBit = countBits(betMask);

        bet.amount = amount;
        bet.numOfBetBit = numOfBetBit;
        bet.placeBlockNumber = block.number;
        bet.mask = betMask;
        bet.gambler = msg.sender;

        // need to lock possible winning amount to pay
        uint possibleWinningAmount = getWinningAmount(amount, numOfBetBit);
        lockedInBets += possibleWinningAmount;

        // Check whether house has enough ETH to pay the bet.
        require(lockedInBets < address(this).balance, "Cannnot afford to pay the bet.");
    }


    function getWinningAmount(uint amount, uint8 numOfBetBit) private pure returns (uint winningAmount) {
        require (0 < numOfBetBit && numOfBetBit < MAX_CASE, "Probability is out of range"); // 1

        uint houseFee = amount * HOUSE_FEE_PERCENT / 100;

        if(houseFee < HOUSE_MIN_FEE) {
            houseFee = HOUSE_MIN_FEE;
        }

        //reward calculation is depends on your own idea

        uint reward = amount / (MAX_CASE + (numOfBetBit-1));

        winningAmount = (amount - houseFee) + reward;
    }


    //Reveal  the coin by player
    function revealResult(uint8 seed) external {

        Bet storage bet = bets[msg.sender];
        uint amount = bet.amount;
        uint8 numOfBetBit = bet.numOfBetBit;
        uint placeBlockNumber = bet.placeBlockNumber;
        address gambler = bet.gambler;

        require (amount > 0, "Bet should be in an 'active' state");

        //should be called after placeBet
        require(block.number > placeBlockNumber, "revealResult in the same block as placeBet, or before.");

        //RNG(Random Number Gennerator)
        bytes32 random = keccak256(abi.encodePacked(blockhash(block.number-seed), blockhash(placeBlockNumber)));

        uint reveal = uint(random) % MAX_CASE; // 0 or 1

        uint winningAmount = 0;
        uint possibleWinningAmount = 0;
        possibleWinningAmount = getWinningAmount(amount, numOfBetBit);

        if((2 ** reveal) & bet.mask != 0) {
            winningAmount = possibleWinningAmount;
        }

        emit Reveal(2 ** reveal);

        if(winningAmount > 0) {
            sendFunds(gambler, winningAmount);
        }

        lockedInBets -= possibleWinningAmount;
        clearBet(msg.sender);
    }


    function clearBet(address player) private {
        Bet storage bet = bets[player];

        if(bet.amount > 0) { // for safety
            return;
        }

        bet.amount = 0;
        bet.numOfBetBit = 0;
        bet.placeBlockNumber = 0;
        bet.mask = 0;
        bet.gambler = address(0); // null
    }

    function refundBet() external {
        //Check that bet has been already mined.
        require(block.number > bet.placeBlockNumber, "refundBet in the same block as placeBet, or before.");

        Bet storage bet = bets[msg.sender];
        uint amount = bet.amount;

        require (amount > 0, "Bet should be in an 'active' state");

        uint8 numOfBetBit = bet.numOfBetBit;

        // send the refund
        sendFunds(bet.gambler, amount);

        uint possibleWinningAmount;
        possibleWinningAmount = getWinningAmount(amount, numOfBetBit);

        lockedInBets -= possibleWinningAmount;
        clearBet(msg.sender);
    }

    function checkHouseFund() public view onlyOwner returns(uint) {
        return address(this).balance;
    }

    function countBits(uint8 _num) internal pure returns (uint8) {
        uint8 count;
        while (_num > 0) {
            count += _num & 1;
            _num >>= 1;
        }
        return count;
    } 


}
