// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface IERC20Mintable {
    function transfer(address to, uint256 amt) external returns (bool);
}

contract VestingVault {
    struct Grant {
        uint128 total;
        uint128 claimed;
        uint64  start;
        uint64  cliff;
        uint64  duration;
    }

    IERC20Mintable public immutable token;
    address public immutable owner;

    mapping(address => Grant) public grants;

    // Custom errors (gas-cheap)
    error NotOwner();
    error InvalidParams();
    error GrantExists();
    error NoGrant();
    error NothingToClaim();
    error TransferFailed();
    error Reentrancy();

    uint256 private _lock; // 0 = unlocked, 1 = locked

    constructor(IERC20Mintable _token) {
        token = _token;
        owner = msg.sender;
    }

    function addGrant(
        address beneficiary,
        uint128 amount,
        uint64  cliffSeconds,
        uint64  durationSeconds
    ) external {
        if (msg.sender != owner) revert NotOwner();
        if (beneficiary == address(0) || amount == 0) revert InvalidParams();
        if (durationSeconds == 0 || cliffSeconds > durationSeconds) revert InvalidParams();
        if (grants[beneficiary].total != 0) revert GrantExists();

        grants[beneficiary] = Grant({
            total: amount,
            claimed: 0,
            start: uint64(block.timestamp),
            cliff: cliffSeconds,
            duration: durationSeconds
        });
    }

    function vestedOf(address account) public view returns (uint256) {
        Grant memory g = grants[account];
        if (g.total == 0) return 0;

        uint256 start_ = uint256(g.start);
        uint256 cliffTime = start_ + uint256(g.cliff);
        uint256 now_ = block.timestamp;

        if (now_ < cliffTime) return 0;

        uint256 endTime = start_ + uint256(g.duration);
        if (now_ >= endTime) return uint256(g.total);

        // Linear vesting from (start + cliff) to (start + duration)
        uint256 linearDuration = uint256(g.duration) - uint256(g.cliff);
        uint256 elapsed = now_ - cliffTime;
        return (uint256(g.total) * elapsed) / linearDuration;
    }

    function claimableOf(address account) public view returns (uint256) {
        Grant memory g = grants[account];
        if (g.total == 0) return 0;
        uint256 vested = vestedOf(account);
        uint256 claimed = uint256(g.claimed);
        if (vested <= claimed) return 0;
        unchecked { return vested - claimed; }
    }

    /// @notice Anyone can call; tokens always go to msg.sender.
    function claim() external {
        if (_lock != 0) revert Reentrancy();
        _lock = 1;

        Grant storage g = grants[msg.sender];
        if (g.total == 0) { _lock = 0; revert NoGrant(); }

        uint256 vested = vestedOf(msg.sender);
        uint256 claimed = uint256(g.claimed);
        if (vested <= claimed) { _lock = 0; revert NothingToClaim(); }

        uint256 amt;
        unchecked { amt = vested - claimed; }

        // Effects
        unchecked { g.claimed = uint128(claimed + amt); }

        // Interaction
        bool ok = token.transfer(msg.sender, amt);
        if (!ok) {
            // Rollback effect if token returns false
            unchecked { g.claimed = uint128(claimed); }
            _lock = 0;
            revert TransferFailed();
        }

        _lock = 0;
    }
}
