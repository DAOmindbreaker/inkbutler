// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface IRewardsController {
    function claimAllRewards(address[] calldata assets, address to) external returns (uint256);
    function claimAllRewardsToSelf(address[] calldata assets) external returns (uint256);
    function getUserRewards(address[] calldata assets, address user, address reward) external view returns (uint256);
    function getAllUserRewards(address[] calldata assets, address user)
        external view returns (address[] memory rewardsList, uint256[] memory unclaimedAmounts);
}
