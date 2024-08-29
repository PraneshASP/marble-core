// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface IPOUFPaymentModel {
    function initialize(address _creatorNFT, uint256 _tokenId, uint256 _subscriptionPrice) external;
}