# Decentralized Voting Protocol

A gas-optimized, tamper-resistant smart contract protocol on Ethereum ensuring single-vote invariants, discrete election workflow stages, and real-time event indexing for decentralized governance.

---

## 1. Overview

Traditional electronic voting systems suffer from centralized points of failure, opaque tallying processes, and unverifiable audit trails. **Decentralized Voting Protocol** anchors candidate registrations, ballot state transitions, and voter tallies to Ethereum smart contracts:

- **Single-Vote Invariant:** Enforced via `mapping(address => bool) public hasVoted` and atomic revert guards, preventing double-voting attacks.
- **Workflow State Engine:** Discrete stages (`Registering` $\to$ `Voting` $\to$ `Ended`) prevent late candidate registrations, premature voting, and post-deadline ballot tampering.
- **Gas-Optimized Accounting:** Custom Solidity errors (`OnlyAdmin()`, `AlreadyVoted()`, etc.) and internal counters minimize gas overhead.
- **Real-Time Event Streams:** Every state change emits structured events (`CandidateAdded`, `VotingSessionStarted`, `VoteCast`, `VotingSessionEnded`) for direct integration with subgraphs and indexers.

---

## 2. Architecture & State Machine

```
   [ Admin Deploys Contract ]
                │
                ▼
      ┌──────────────────┐
      │   Registering    │ ◄── Admin registers candidate names
      └─────────┬────────┘     (Rejects empty names, requires >= 2)
                │ startVotingSession()
                ▼
      ┌──────────────────┐
      │      Voting      │ ◄── Voters cast 1 vote for Candidate ID
      └─────────┬────────┘     (Enforces single-vote, rejects out-of-bounds)
                │ endVotingSession()
                ▼
      ┌──────────────────┐
      │      Ended       │ ◄── Tally locked; getWinningCandidate()
      └──────────────────┘     (Rejects new votes)
```

---

## 3. Smart Contract Specifications

### 3.1 State Variables
- `address public immutable admin`: Initialized to deployer address.
- `WorkflowStatus public workflowStatus`: Current stage of election (`Registering`, `Voting`, `Ended`).
- `uint256 public candidatesCount`: Total registered candidates.
- `uint256 public totalVotes`: Total votes cast across all candidates.
- `mapping(uint256 => Candidate) public candidates`: 1-based candidate registry storing ID, name, and vote tally.
- `mapping(address => bool) public hasVoted`: Tracks voter participation to prevent double-voting.

### 3.2 Key Methods
- `addCandidate(string memory _name)`: Admin registers candidate during `Registering`.
- `startVotingSession()`: Admin opens election if $\ge 2$ candidates are registered.
- `vote(uint256 _candidateId)`: Eligible account casts vote during `Voting`.
- `endVotingSession()`: Admin closes election and emits winning candidate ID.
- `getCandidate(uint256 _id)`: View candidate name and vote count.
- `getAllCandidates()`: View all registered candidates in a single batch call.
- `getWinningCandidate()`: Evaluates and returns the leading candidate and tally.

---

## 4. Getting Started

### Prerequisites
- Node.js 20+ LTS
- npm

### Installation
```bash
git clone https://github.com/Jaishmon-codes/Voting-System.git
cd Voting-System
npm install
```

### Compile
```bash
npx hardhat compile
```

### Run Tests
```bash
npx hardhat test
```

---

## 5. Security & Verification

- **Reentrancy Protection:** All state modifications occur before event emissions; no external calls or transfers are executed.
- **Access Control:** Restricted admin methods enforce `onlyAdmin` modifier with custom revert errors.
- **Zero Double-Voting:** Addresses are marked `hasVoted = true` atomically before incrementing candidate tallies.
- **Automated CI:** GitHub Actions verifies contract compilation and executes the 10-test invariant test suite on every push.

---

## 6. License
MIT License. Created by [Jaishmon M](https://github.com/Jaishmon-codes).
