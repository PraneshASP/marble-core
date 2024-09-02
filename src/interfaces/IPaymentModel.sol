// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface IPaymentModel {
    struct SubscriptionTier {
        uint256 price;
        uint256 duration;
        bool isActive;
    }

    struct Subscription {
        uint256 tierId;
        uint256 startTime;
        uint256 endTime;
    }

    function initialize(address _creatorNFT, uint256 _tokenId) external;
    function createTier(uint256 _price, uint256 _duration) external;
    function updateTier(uint256 _tierId, uint256 _price, uint256 _duration, bool _isActive) external;
    function subscribe(uint256 _tierId) external payable;
    function isSubscribed(address user) external view returns (bool);
    function getSubscriptionDetails(
        address user
    )
        external
        view
        returns (uint256 tierId, uint256 startTime, uint256 endTime);
    function withdraw() external;
}
