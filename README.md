# AgentPoll — One Agent ID, One Vote

Sybil-resistant on-chain polls for the agent economy, built on BNB Chain for the
Binance Wallet × BNB Chain **Agent ID Hackathon**.

## Why Agent ID?

Online polls and DAO votes are broken by sockpuppets: one person spins up a
thousand wallets and outvotes everyone. Token-weighted voting just replaces
that with plutocracy.

An **Agent ID** is different. It is issued **once per person** and is
**non-transferable** — it is an identity, not an asset. AgentPoll gates poll
creation and voting on Agent ID ownership, so every real agent gets exactly
**one voice per poll**. No token weighting, no bought votes, no sockpuppets.

## How it works

- The `AgentPoll` contract checks `balanceOf(creator/voter)` on the official
  Agent ID registry (SPACE ID Agent ID, `0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F`
  on BNB Chain) before allowing `createPoll` or `vote`.
- A poll has a question, 2–6 options, and a voting window of 1 hour to 30 days.
- One vote per Agent ID holder address per poll. Votes are final and counted
  on-chain in real time (`getPoll` / `getCounts`).
- The contract **holds no funds**, has **no owner and no admin functions**, and
  is **immutable** — nobody can change a result, censor a voter, or upgrade the
  rules after deployment.

## Contract

- Network: BNB Chain (BSC, chain id 56)
- `AgentPoll` address: 0xa6E4E207fab3830718c0Be73e56fd2D9d7d0311e (deployed 2026-11-19, tx 0xa801170c884e73ccfe7f295cad21e2c92918ff96e53db68fa58fb882930b9b18)
- Agent ID registry: `0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F`
- Source: `src/AgentPoll.sol` — a single self-contained file, no dependencies,
  verified on BscScan.

## Build & test

Requires [Foundry](https://getfoundry.sh).

```bash
forge build
forge test
```

The test suite (9 tests) covers the Agent ID gate for creating and voting,
one-vote-per-address enforcement, vote counting, poll expiry, and input
validation, using a mock registry.

## License

MIT — see `LICENSE`.
