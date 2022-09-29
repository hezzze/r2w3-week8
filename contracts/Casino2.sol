//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Casino2 is Ownable {
    uint256 public timeToRespond = 60; // time to respond default is 60s

    struct ProposedBet {
        address sideA;
        uint256 value;
        uint256 placedAt;
        bool accepted;
        bool aRevealed;
        uint256 randomA;
        uint256 revealedAt;
    } // struct ProposedBet

    struct AcceptedBet {
        address sideB;
        uint256 acceptedAt;
        uint256 hashB;
    } // struct AcceptedBet

    // Proposed bets, keyed by the commitment value
    mapping(uint256 => ProposedBet) public proposedBet;

    // Accepted bets, also keyed by commitment value
    mapping(uint256 => AcceptedBet) public acceptedBet;

    event BetProposed(uint256 indexed _commitment, uint256 value);

    event BetAccepted(uint256 indexed _commitment, address indexed _sideA);

    event BetOneSideRevealed(uint256 indexed _commitment, uint256 revealedAt);

    event BetSettled(
        uint256 indexed _commitment,
        address winner,
        address loser,
        uint256 value
    );

    // Called by sideA to start the process
    function proposeBet(uint256 _commitmentA) external payable {
        require(
            proposedBet[_commitmentA].value == 0,
            "there is already a bet on that commitment"
        );
        require(msg.value > 0, "you need to actually bet something");

        proposedBet[_commitmentA].sideA = msg.sender;
        proposedBet[_commitmentA].value = msg.value;
        proposedBet[_commitmentA].placedAt = block.timestamp;
        // accepted is false by default

        emit BetProposed(_commitmentA, msg.value);
    } // function proposeBet

    // Called by sideB to continue
    function acceptBet(uint256 _commitmentA, uint256 _commitmentB)
        external
        payable
    {
        require(
            !proposedBet[_commitmentA].accepted,
            "Bet has already been accepted"
        );
        require(
            proposedBet[_commitmentA].sideA != address(0),
            "Nobody made that bet"
        );
        require(
            msg.value == proposedBet[_commitmentA].value,
            "Need to bet the same amount as sideA"
        );

        acceptedBet[_commitmentA].sideB = msg.sender;
        acceptedBet[_commitmentA].acceptedAt = block.timestamp;
        acceptedBet[_commitmentA].hashB = _commitmentB;
        proposedBet[_commitmentA].accepted = true;

        emit BetAccepted(_commitmentA, proposedBet[_commitmentA].sideA);
    } // function acceptBet

    // Called by sideA to reveal their random value, sideB needs to reveal
    // within a short amount of time after sideA is revealed or
    // sideA can call forfeit and take the bet value
    function reveal(uint256 _randomA) external {
        uint256 _commitmentA = uint256(keccak256(abi.encodePacked(_randomA)));
        // make sure A is commited
        require(
            proposedBet[_commitmentA].sideA == msg.sender,
            "Not a bet you placed or wrong value"
        );
        require(
            proposedBet[_commitmentA].accepted,
            "Bet has not been accepted yet"
        );
        proposedBet[_commitmentA].aRevealed = true;
        proposedBet[_commitmentA].revealedAt = block.timestamp;
        proposedBet[_commitmentA].randomA = _randomA;

        emit BetOneSideRevealed(
            _commitmentA,
            proposedBet[_commitmentA].revealedAt
        );
    } // function reveal

    // if sideB is not responding in time, sideA can call this to
    // forfeit and take the bet
    function forfeit(uint256 _commitmentA) external {
        require(
            proposedBet[_commitmentA].accepted &&
                proposedBet[_commitmentA].aRevealed,
            "Bet has not been accepted/revealed yet"
        );
        require(
            block.timestamp - proposedBet[_commitmentA].revealedAt >
                timeToRespond,
            "still within response time"
        );

        address payable _sideA = payable(msg.sender);
        address payable _sideB = payable(acceptedBet[_commitmentA].sideB);

        // sideA wins
        uint256 _value = proposedBet[_commitmentA].value;
        _sideA.transfer(2 * _value);
        emit BetSettled(_commitmentA, _sideA, _sideB, _value);

        // clean up
        delete proposedBet[_commitmentA];
        delete acceptedBet[_commitmentA];
    }

    // Called by sideB to conclude the results
    function conclude(uint256 _commitmentA, uint256 _randomB) external {
        uint256 _commitmentB = uint256(keccak256(abi.encodePacked(_randomB)));
        require(
            proposedBet[_commitmentA].accepted &&
                proposedBet[_commitmentA].aRevealed,
            "Bet has not been accepted/revealed yet"
        );
        require(
            block.timestamp - proposedBet[_commitmentA].revealedAt <=
                timeToRespond,
            "failed to conclude the bet in time"
        );

        // make sure B is commited
        require(
            acceptedBet[_commitmentA].hashB == _commitmentB &&
                acceptedBet[_commitmentA].sideB == msg.sender,
            "Not a bet you placed or wrong value"
        );

        address payable _sideB = payable(msg.sender);
        address payable _sideA = payable(proposedBet[_commitmentA].sideA);
        uint256 _agreedRandom = _randomB ^ proposedBet[_commitmentA].randomA;
        uint256 _value = proposedBet[_commitmentA].value;

        // Pay and emit an event
        if (_agreedRandom % 2 == 0) {
            // sideA wins
            _sideA.transfer(2 * _value);
            emit BetSettled(_commitmentA, _sideA, _sideB, _value);
        } else {
            // sideB wins
            _sideB.transfer(2 * _value);
            emit BetSettled(_commitmentA, _sideB, _sideA, _value);
        }

        // Cleanup
        delete proposedBet[_commitmentA];
        delete acceptedBet[_commitmentA];
    } // function conclude

    function setTimeToReveal(uint256 _time) public onlyOwner {
        timeToRespond = _time;
    }
} // contract Casino
