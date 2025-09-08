// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
}

contract VestingVault {
    struct Grant {
        uint128 total;
        uint128 claimed;
        uint64  start;
        uint64  cliff;
        uint64  duration;
    }

    IERC20 public immutable token;
    address public immutable owner;

    mapping(address => Grant) public grants;

    constructor(IERC20 _token) {
        token = _token;
        owner = msg.sender;
    }

    function addGrant(
        address beneficiary,
        uint128 amount,
        uint64  cliff,
        uint64  duration
    ) external {
        require(msg.sender == owner, "not owner");
        grants[beneficiary] = Grant({
            total: amount,
            claimed: 0,
            start: uint64(block.timestamp),
            cliff: cliff,
            duration: duration
        });
    }

    function vestedOf(address account) public view returns (uint256) {
        Grant memory g = grants[account];
        if (g.total == 0) return 0;

        uint256 cliffTime = g.start + g.cliff;
        if (block.timestamp < cliffTime) return 0;

        uint256 end = g.start + g.duration;
        if (block.timestamp >= end) return g.total;

        uint256 elapsed = block.timestamp - cliffTime;
        uint256 vestingTime = g.duration - g.cliff;
        return (g.total * elapsed) / vestingTime;
    }

    function claim() external {
        Grant storage g = grants[msg.sender];
        uint256 vested = vestedOf(msg.sender);
        uint256 claimable = vested - g.claimed;
        require(claimable > 0, "nothing");

        g.claimed += uint128(claimable);
        token.transfer(msg.sender, claimable);
    }
}
