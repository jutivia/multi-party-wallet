
# Multi-Party Wallet
A muti-party wallet designed such that:
- It has one administrator to the contract who can add or remove the address from the owners of the wallet contract.
- Any of the owners can submit a new transaction proposal.
- The remaining owners can approve the proposal.
- Then the user who submitted the proposal can call a function executeProposal.
- The proposal can be executed only if at least 60% of the owners have approved the proposal.
- The administrator should be able to change the % of approvals needed to execute the proposal.

# Tech Stack
- solididty
- Hardhat
- Typescript
- Typechain
