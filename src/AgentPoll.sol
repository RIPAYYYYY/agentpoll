// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Minimal interface of the Binance Agent ID registry
///         (SPACE ID Agent ID on BNB Chain, ERC-721, non-transferable).
interface IAgentIdRegistry {
    function balanceOf(address owner) external view returns (uint256);
}

/// @title AgentPoll — one Agent ID, one vote.
/// @notice Sybil-resistant on-chain polls for the agent economy.
///         An Agent ID is issued once per person and can never be transferred,
///         so gating polls by Agent ID ownership gives every real agent exactly
///         one voice — no token weighting, no bought votes, no sockpuppets.
///         Only Agent ID holders can create polls and vote. The contract holds
///         no funds, has no owner and no admin functions, and is immutable.
contract AgentPoll {
    /// @notice The Agent ID registry this deployment trusts.
    IAgentIdRegistry public immutable agentIdRegistry;

    struct Poll {
        address creator;
        string question;
        uint64 endsAt;
        uint256 totalVotes;
        string[] options;
    }

    Poll[] private _polls;
    mapping(uint256 => uint256[]) private _counts;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(uint256 => mapping(address => uint8)) public choiceOf;

    event PollCreated(
        uint256 indexed pollId,
        address indexed creator,
        string question,
        uint64 endsAt,
        uint256 optionCount
    );
    event Voted(uint256 indexed pollId, address indexed voter, uint8 option);

    constructor(address registry) {
        require(registry != address(0), "AgentPoll: registry is zero address");
        agentIdRegistry = IAgentIdRegistry(registry);
    }

    modifier onlyAgentIdHolder() {
        require(agentIdRegistry.balanceOf(msg.sender) > 0, "AgentPoll: Agent ID required");
        _;
    }

    /// @notice Create a poll. Only Agent ID holders can create.
    /// @param question The poll question (3-200 bytes).
    /// @param options 2-6 answer options (1-80 bytes each).
    /// @param durationHours Voting window in hours (1 to 720 = 30 days).
    function createPoll(string calldata question, string[] calldata options, uint64 durationHours)
        external
        onlyAgentIdHolder
        returns (uint256 pollId)
    {
        uint256 qLen = bytes(question).length;
        require(qLen >= 3 && qLen <= 200, "AgentPoll: bad question length");
        require(options.length >= 2 && options.length <= 6, "AgentPoll: need 2-6 options");
        require(durationHours >= 1 && durationHours <= 720, "AgentPoll: bad duration");
        for (uint256 i = 0; i < options.length; i++) {
            uint256 oLen = bytes(options[i]).length;
            require(oLen >= 1 && oLen <= 80, "AgentPoll: bad option length");
        }

        pollId = _polls.length;
        _polls.push();
        Poll storage p = _polls[pollId];
        p.creator = msg.sender;
        p.question = question;
        p.endsAt = uint64(block.timestamp) + durationHours * 1 hours;
        for (uint256 i = 0; i < options.length; i++) {
            p.options.push(options[i]);
        }
        _counts[pollId] = new uint256[](options.length);

        emit PollCreated(pollId, msg.sender, question, p.endsAt, options.length);
    }

    /// @notice Vote in a poll. One vote per Agent ID holder address, final.
    function vote(uint256 pollId, uint8 option) external onlyAgentIdHolder {
        require(pollId < _polls.length, "AgentPoll: no such poll");
        Poll storage p = _polls[pollId];
        require(block.timestamp < p.endsAt, "AgentPoll: poll ended");
        require(option < p.options.length, "AgentPoll: bad option");
        require(!hasVoted[pollId][msg.sender], "AgentPoll: already voted");

        hasVoted[pollId][msg.sender] = true;
        choiceOf[pollId][msg.sender] = option;
        _counts[pollId][option] += 1;
        p.totalVotes += 1;

        emit Voted(pollId, msg.sender, option);
    }

    function pollCount() external view returns (uint256) {
        return _polls.length;
    }

    /// @notice Full read of one poll, including live per-option counts.
    function getPoll(uint256 pollId)
        external
        view
        returns (
            address creator,
            string memory question,
            string[] memory options,
            uint256[] memory counts,
            uint64 endsAt,
            uint256 totalVotes,
            bool ended
        )
    {
        require(pollId < _polls.length, "AgentPoll: no such poll");
        Poll storage p = _polls[pollId];
        return (
            p.creator,
            p.question,
            p.options,
            _counts[pollId],
            p.endsAt,
            p.totalVotes,
            block.timestamp >= p.endsAt
        );
    }

    function getCounts(uint256 pollId) external view returns (uint256[] memory) {
        require(pollId < _polls.length, "AgentPoll: no such poll");
        return _counts[pollId];
    }
}
