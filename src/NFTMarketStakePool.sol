// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {NFTMarket} from "./NFTMarket.sol";

contract NFTMarketStakePool {
    NFTMarket public nftMarket;

    struct UserStakeInfo {
        uint128 amount;
        uint128 rewards;
        uint256 index;
    }

    mapping(address => UserStakeInfo) public stakes;
    uint256 public totalStaked;
    uint256 public poolIndex;
    uint256 public totalRewards;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event Claimed(address indexed user, uint256 amount);

    constructor(address _nftMarket) {
        nftMarket = NFTMarket(_nftMarket);
    }

    function stake() external payable {
        require(msg.value > 0, "Invalid amount");
        _calculateReward(msg.sender);
        stakes[msg.sender].amount += uint128(msg.value);
        totalStaked += msg.value;
        emit Staked(msg.sender, msg.value);
    }

    function unstake(uint128 amount) external {
        require(amount > 0, "Invalid amount");
        require(stakes[msg.sender].amount >= amount, "Insufficient staked amount");
        _calculateReward(msg.sender);
        stakes[msg.sender].amount -= amount;
        totalStaked -= amount;
        (bool success,) = payable(msg.sender).call{value: amount}("");
        require(success, "Unstake transfer failed");
        emit Unstaked(msg.sender, amount);
    }

    function claim() external {
        _calculateReward(msg.sender);
        uint128 reward = stakes[msg.sender].rewards;
        require(reward > 0, "No reward to claim");
        stakes[msg.sender].rewards = 0;
        totalRewards -= reward;
        (bool success,) = payable(msg.sender).call{value: reward}("");
        require(success, "Transfer failed to claim");
        emit Claimed(msg.sender, reward);
    }

    function _calculateReward(address account) internal {
        UserStakeInfo memory info = stakes[account];

        // uint256 rewards = (info.amount * (poolIndex - info.index)) / 1e18;
        // stakes[account].rewards += rewards;
        // stakes[account].index = poolIndex;

        info.rewards += uint128((info.amount * (poolIndex - info.index)) / 1e18);
        info.index = poolIndex;

        stakes[account] = info;
    }

    function getStakes(address _user) external view returns (UserStakeInfo memory) {
        return stakes[_user];
    }

    receive() external payable {
        require(msg.sender == address(nftMarket), "Invalid sender");
        totalRewards += msg.value;
        if (totalStaked > 0) {
            poolIndex += msg.value * 1e18 / totalStaked;
        }
    }
}
