// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title DecentralizedVoting
 * @notice Tamper-resistant, on-chain voting protocol ensuring single-vote invariants,
 *         granular workflow stages, and real-time event indexing.
 * @author Jaishmon M
 */
contract DecentralizedVoting {
    // --- Custom Errors ---
    error OnlyAdmin();
    error EmptyCandidateName();
    error CandidateRegistrationClosed();
    error VotingNotOpen();
    error VotingAlreadyEnded();
    error AlreadyVoted();
    error InvalidCandidateId();
    error InsufficientCandidates();
    error NoVotesCast();

    // --- State & Enums ---
    enum WorkflowStatus {
        Registering,
        Voting,
        Ended
    }

    struct Candidate {
        uint256 id;
        string name;
        uint256 voteCount;
    }

    address public immutable admin;
    WorkflowStatus public workflowStatus;
    uint256 public candidatesCount;
    uint256 public totalVotes;

    mapping(uint256 => Candidate) public candidates;
    mapping(address => bool) public hasVoted;

    // --- Events ---
    event CandidateAdded(uint256 indexed candidateId, string name);
    event VotingSessionStarted(uint256 indexed timestamp);
    event VoteCast(address indexed voter, uint256 indexed candidateId, uint256 newVoteCount);
    event VotingSessionEnded(uint256 indexed timestamp, uint256 indexed winningCandidateId);

    // --- Modifiers ---
    modifier onlyAdmin() {
        if (msg.sender != admin) revert OnlyAdmin();
        _;
    }

    constructor() {
        admin = msg.sender;
        workflowStatus = WorkflowStatus.Registering;
    }

    /**
     * @notice Adds a new candidate to the ballot. Can only be invoked by admin during Registering stage.
     * @param _name Name of the candidate
     */
    function addCandidate(string memory _name) public onlyAdmin {
        if (workflowStatus != WorkflowStatus.Registering) revert CandidateRegistrationClosed();
        if (bytes(_name).length == 0) revert EmptyCandidateName();

        candidatesCount++;
        candidates[candidatesCount] = Candidate({
            id: candidatesCount,
            name: _name,
            voteCount: 0
        });

        emit CandidateAdded(candidatesCount, _name);
    }

    /**
     * @notice Transitions ballot from Registering to Voting. Requires at least 2 candidates.
     */
    function startVotingSession() external onlyAdmin {
        if (workflowStatus != WorkflowStatus.Registering) revert CandidateRegistrationClosed();
        if (candidatesCount < 2) revert InsufficientCandidates();

        workflowStatus = WorkflowStatus.Voting;
        emit VotingSessionStarted(block.timestamp);
    }

    /**
     * @notice Casts a single vote for a registered candidate. Enforces single-vote invariant.
     * @param _candidateId 1-based index of the chosen candidate
     */
    function vote(uint256 _candidateId) public {
        if (workflowStatus != WorkflowStatus.Voting) revert VotingNotOpen();
        if (hasVoted[msg.sender]) revert AlreadyVoted();
        if (_candidateId == 0 || _candidateId > candidatesCount) revert InvalidCandidateId();

        hasVoted[msg.sender] = true;
        candidates[_candidateId].voteCount++;
        totalVotes++;

        emit VoteCast(msg.sender, _candidateId, candidates[_candidateId].voteCount);
    }

    /**
     * @notice Closes voting session. Can only be invoked by admin.
     */
    function endVotingSession() external onlyAdmin {
        if (workflowStatus != WorkflowStatus.Voting) revert VotingNotOpen();

        workflowStatus = WorkflowStatus.Ended;
        (uint256 winnerId,,) = getWinningCandidate();
        emit VotingSessionEnded(block.timestamp, winnerId);
    }

    /**
     * @notice Fetches details of a candidate by ID.
     * @param _id 1-based index of the candidate
     */
    function getCandidate(uint256 _id) public view returns (string memory, uint256) {
        if (_id == 0 || _id > candidatesCount) revert InvalidCandidateId();
        return (candidates[_id].name, candidates[_id].voteCount);
    }

    /**
     * @notice Fetches all candidates in a single batch read for efficient UI rendering.
     */
    function getAllCandidates() external view returns (Candidate[] memory) {
        Candidate[] memory list = new Candidate[](candidatesCount);
        for (uint256 i = 1; i <= candidatesCount; i++) {
            list[i - 1] = candidates[i];
        }
        return list;
    }

    /**
     * @notice Calculates the winning candidate based on highest vote tally.
     * @return winnerId 1-based index of the candidate
     * @return winnerName Name of the winning candidate
     * @return winnerVoteCount Total votes accumulated by the winner
     */
    function getWinningCandidate() public view returns (
        uint256 winnerId,
        string memory winnerName,
        uint256 winnerVoteCount
    ) {
        if (candidatesCount == 0) revert InsufficientCandidates();

        uint256 highestVotes = 0;
        uint256 winningId = 1;

        for (uint256 i = 1; i <= candidatesCount; i++) {
            if (candidates[i].voteCount > highestVotes) {
                highestVotes = candidates[i].voteCount;
                winningId = i;
            }
        }

        return (winningId, candidates[winningId].name, highestVotes);
    }
}
