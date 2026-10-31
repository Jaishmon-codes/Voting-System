const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("DecentralizedVoting Protocol", function () {
  let voting;
  let admin, voter1, voter2, voter3, nonAdmin;

  beforeEach(async function () {
    [admin, voter1, voter2, voter3, nonAdmin] = await ethers.getSigners();

    const VotingFactory = await ethers.getContractFactory("DecentralizedVoting");
    voting = await VotingFactory.deploy();
    await voting.waitForDeployment();
  });

  describe("Initialization & Access Control", function () {
    it("should initialize with correct admin and Registering status", async function () {
      expect(await voting.admin()).to.equal(admin.address);
      expect(await voting.workflowStatus()).to.equal(0); // Registering
      expect(await voting.candidatesCount()).to.equal(0);
      expect(await voting.totalVotes()).to.equal(0);
    });

    it("should allow admin to register candidates", async function () {
      await expect(voting.connect(admin).addCandidate("Alice"))
        .to.emit(voting, "CandidateAdded")
        .withArgs(1, "Alice");

      expect(await voting.candidatesCount()).to.equal(1);
      const [name, count] = await voting.getCandidate(1);
      expect(name).to.equal("Alice");
      expect(count).to.equal(0);
    });

    it("should prevent non-admin from adding candidates", async function () {
      await expect(
        voting.connect(nonAdmin).addCandidate("Mallory")
      ).to.be.revertedWithCustomError(voting, "OnlyAdmin");
    });

    it("should reject empty candidate names", async function () {
      await expect(
        voting.connect(admin).addCandidate("")
      ).to.be.revertedWithCustomError(voting, "EmptyCandidateName");
    });
  });

  describe("Session Lifecycle & Transitions", function () {
    it("should prevent starting voting session with fewer than 2 candidates", async function () {
      await voting.connect(admin).addCandidate("Alice");
      await expect(
        voting.connect(admin).startVotingSession()
      ).to.be.revertedWithCustomError(voting, "InsufficientCandidates");
    });

    it("should transition workflow status to Voting when session starts", async function () {
      await voting.connect(admin).addCandidate("Alice");
      await voting.connect(admin).addCandidate("Bob");

      await expect(voting.connect(admin).startVotingSession())
        .to.emit(voting, "VotingSessionStarted");

      expect(await voting.workflowStatus()).to.equal(1); // Voting
    });

    it("should reject adding new candidates once voting has started", async function () {
      await voting.connect(admin).addCandidate("Alice");
      await voting.connect(admin).addCandidate("Bob");
      await voting.connect(admin).startVotingSession();

      await expect(
        voting.connect(admin).addCandidate("Charlie")
      ).to.be.revertedWithCustomError(voting, "CandidateRegistrationClosed");
    });
  });

  describe("Voting Invariants & Ballot Integrity", function () {
    beforeEach(async function () {
      await voting.connect(admin).addCandidate("Alice");
      await voting.connect(admin).addCandidate("Bob");
      await voting.connect(admin).addCandidate("Charlie");
      await voting.connect(admin).startVotingSession();
    });

    it("should allow eligible voters to cast a vote and emit VoteCast", async function () {
      await expect(voting.connect(voter1).vote(1))
        .to.emit(voting, "VoteCast")
        .withArgs(voter1.address, 1, 1);

      expect(await voting.hasVoted(voter1.address)).to.be.true;
      expect(await voting.totalVotes()).to.equal(1);

      const [, count] = await voting.getCandidate(1);
      expect(count).to.equal(1);
    });

    it("should enforce single-vote invariant and reject double voting", async function () {
      await voting.connect(voter1).vote(1);

      await expect(
        voting.connect(voter1).vote(1)
      ).to.be.revertedWithCustomError(voting, "AlreadyVoted");

      await expect(
        voting.connect(voter1).vote(2)
      ).to.be.revertedWithCustomError(voting, "AlreadyVoted");
    });

    it("should reject votes for out-of-bounds candidate IDs", async function () {
      await expect(
        voting.connect(voter1).vote(0)
      ).to.be.revertedWithCustomError(voting, "InvalidCandidateId");

      await expect(
        voting.connect(voter1).vote(99)
      ).to.be.revertedWithCustomError(voting, "InvalidCandidateId");
    });

    it("should accurately compute winner and close election", async function () {
      await voting.connect(voter1).vote(2); // Bob
      await voting.connect(voter2).vote(2); // Bob
      await voting.connect(voter3).vote(1); // Alice

      const [winnerId, winnerName, votes] = await voting.getWinningCandidate();
      expect(winnerId).to.equal(2);
      expect(winnerName).to.equal("Bob");
      expect(votes).to.equal(2);

      await expect(voting.connect(admin).endVotingSession())
        .to.emit(voting, "VotingSessionEnded")
        .withArgs(await ethers.provider.getBlock("latest").then(b => b.timestamp + 1), 2);

      expect(await voting.workflowStatus()).to.equal(2); // Ended

      // Post-close voting rejection
      const [, , , , , voter4] = await ethers.getSigners();
      await expect(
        voting.connect(voter4).vote(1)
      ).to.be.revertedWithCustomError(voting, "VotingNotOpen");
    });

    it("should support batch retrieval of all candidates", async function () {
      const candidates = await voting.getAllCandidates();
      expect(candidates.length).to.equal(3);
      expect(candidates[0].name).to.equal("Alice");
      expect(candidates[1].name).to.equal("Bob");
      expect(candidates[2].name).to.equal("Charlie");
    });
  });
});
