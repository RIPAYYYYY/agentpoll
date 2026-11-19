// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AgentPoll} from "../src/AgentPoll.sol";

interface Vm {
    function warp(uint256 newTimestamp) external;
    function prank(address msgSender) external;
    function expectRevert(bytes calldata revertData) external;
}

/// @notice Stand-in for the Agent ID registry: balanceOf is all AgentPoll reads.
contract MockRegistry {
    mapping(address => uint256) private _balances;
    function set(address who, uint256 n) external { _balances[who] = n; }
    function balanceOf(address owner) external view returns (uint256) { return _balances[owner]; }
}

contract AgentPollTest {
    Vm constant vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    MockRegistry registry;
    AgentPoll poll;
    address alice = address(0xA11CE);
    address bob = address(0xB0B);
    address carol = address(0xCA401);

    function setUp() public {
        registry = new MockRegistry();
        poll = new AgentPoll(address(registry));
        registry.set(alice, 1);
        registry.set(bob, 1);
        // carol holds no Agent ID
    }

    // --- tiny assertion helpers ---
    function assertTrue(bool c, string memory m) internal pure { require(c, m); }
    function assertEq(uint256 a, uint256 b, string memory m) internal pure { require(a == b, m); }
    function assertEq(address a, address b, string memory m) internal pure { require(a == b, m); }
    function assertEq(string memory a, string memory b, string memory m) internal pure {
        require(keccak256(bytes(a)) == keccak256(bytes(b)), m);
    }

    function _options() internal pure returns (string[] memory o) {
        o = new string[](3);
        o[0] = "Yes";
        o[1] = "No";
        o[2] = "Abstain";
    }

    function testNonHolderCannotCreate() public {
        vm.prank(carol);
        vm.expectRevert(bytes("AgentPoll: Agent ID required"));
        poll.createPoll("Is this a real poll?", _options(), 24);
    }

    function testNonHolderCannotVote() public {
        vm.prank(alice);
        poll.createPoll("Is this a real poll?", _options(), 24);
        vm.prank(carol);
        vm.expectRevert(bytes("AgentPoll: Agent ID required"));
        poll.vote(0, 0);
    }

    function testHolderCreatesPoll() public {
        vm.prank(alice);
        uint256 id = poll.createPoll("Best agent framework?", _options(), 48);
        assertEq(id, 0, "first poll id");
        assertEq(poll.pollCount(), 1, "poll count");
        (address creator, string memory q, string[] memory opts, uint256[] memory counts,
         uint64 endsAt, uint256 total, bool ended) = poll.getPoll(0);
        assertEq(creator, alice, "creator persisted");
        assertEq(q, "Best agent framework?", "question persisted");
        assertEq(opts.length, 3, "options persisted");
        assertEq(opts[1], "No", "option text persisted");
        assertEq(counts.length, 3, "counts length");
        assertEq(counts[0], 0, "counts start at zero");
        assertTrue(endsAt > uint64(block.timestamp), "endsAt in future");
        assertEq(total, 0, "no votes yet");
        assertTrue(!ended, "not ended");
    }

    function testVoteCounts() public {
        vm.prank(alice);
        poll.createPoll("Ship it?", _options(), 24);
        vm.prank(alice);
        poll.vote(0, 0);
        vm.prank(bob);
        poll.vote(0, 1);
        uint256[] memory counts = poll.getCounts(0);
        assertEq(counts[0], 1, "option 0 count");
        assertEq(counts[1], 1, "option 1 count");
        assertEq(counts[2], 0, "option 2 count");
        (, , , , , uint256 total, ) = poll.getPoll(0);
        assertEq(total, 2, "total votes");
        assertTrue(poll.hasVoted(0, alice), "alice marked voted");
        assertEq(uint256(poll.choiceOf(0, bob)), 1, "bob choice recorded");
    }

    function testDoubleVoteReverts() public {
        vm.prank(alice);
        poll.createPoll("Ship it?", _options(), 24);
        vm.prank(alice);
        poll.vote(0, 2);
        vm.prank(alice);
        vm.expectRevert(bytes("AgentPoll: already voted"));
        poll.vote(0, 0);
    }

    function testVoteAfterEndReverts() public {
        vm.prank(alice);
        poll.createPoll("Ship it?", _options(), 1);
        vm.warp(block.timestamp + 2 hours);
        vm.prank(bob);
        vm.expectRevert(bytes("AgentPoll: poll ended"));
        poll.vote(0, 0);
    }

    function testBadOptionReverts() public {
        vm.prank(alice);
        poll.createPoll("Ship it?", _options(), 24);
        vm.prank(bob);
        vm.expectRevert(bytes("AgentPoll: bad option"));
        poll.vote(0, 3);
    }

    function testCreateValidation() public {
        string[] memory one = new string[](1);
        one[0] = "Only";
        vm.prank(alice);
        vm.expectRevert(bytes("AgentPoll: need 2-6 options"));
        poll.createPoll("Valid question?", one, 24);

        vm.prank(alice);
        vm.expectRevert(bytes("AgentPoll: bad duration"));
        poll.createPoll("Valid question?", _options(), 0);
    }

    function testZeroRegistryReverts() public {
        vm.expectRevert(bytes("AgentPoll: registry is zero address"));
        new AgentPoll(address(0));
    }
}
