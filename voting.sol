// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DecentralizedVoting {

    struct Candidate {
        uint id;
        string name;
        uint voteCount;
    }

    address public admin;

    mapping(uint => Candidate) public candidates;
    mapping(address => bool) public hasVoted;

    uint public candidatesCount;

    constructor() {
        admin = msg.sender;
    }

    // Add candidate (only admin)
    function addCandidate(string memory _name) public {
        require(msg.sender == admin, "Only admin can add");

        candidatesCount++;

        candidates[candidatesCount] = Candidate(
            candidatesCount,
            _name,
            0
        );
    }

    // Vote
    function vote(uint _candidateId) public {

        require(!hasVoted[msg.sender], "Already voted");

        require(
            _candidateId > 0 && _candidateId <= candidatesCount,
            "Invalid candidate"
        );

        hasVoted[msg.sender] = true;

        candidates[_candidateId].voteCount++;
    }

    // Get results
    function getCandidate(uint _id)
        public
        view
        returns (string memory, uint)
    {
        return (
            candidates[_id].name,
            candidates[_id].voteCount
        );
    }
}
