// SPDX-License-Identifier: MIT

Requirements
Anyone can call claim(), but tokens always go to msg.sender.


Linear vesting after start + cliff; nothing claimable before that.


Gas-efficient: use immutable, unchecked math where safe, custom errors.


Protect against re-entrancy (Checks-Effects-Interactions or nonReentrant).


Tests (Foundry / Hardhat) covering:


“Nothing vested before cliff.”


“Full amount claimable after duration.”
