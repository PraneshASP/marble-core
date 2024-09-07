// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {IERC6551Account} from "./interfaces/IERC6551.sol";

contract PaymentModel is IERC165, IERC1271, IERC6551Account {
    address public creatorNFT;
    uint256 public tokenId;

    bool public isInitialized;

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

    mapping(uint256 => SubscriptionTier) public subscriptionTiers;
    mapping(address => Subscription) public userSubscriptions;
    uint256 public tierCount;

    error Initialized();
    error InvalidAmount();
    error InvalidCaller();
    error AlreadySubscribed();
    error CannotTransferFunds();
    error InvalidSignature();
    error InvalidTier();
    error InactiveTier();

    event SubscriptionCreated(address user, uint256 tierId, uint256 startTime, uint256 endTime);
    event TierCreated(uint256 tierId, uint256 price, uint256 duration);
    event TierUpdated(uint256 tierId, uint256 price, uint256 duration, bool isActive);

    function createTier(uint256 _price, uint256 _duration) external {
        // if (msg.sender != IERC721(creatorNFT).ownerOf(tokenId)) revert InvalidCaller();
        // TODO: Add check via _lzReceive
        tierCount++;
        subscriptionTiers[tierCount] = SubscriptionTier(_price, _duration, true);

        emit TierCreated(tierCount, _price, _duration);
    }

    // function updateTier(uint256 _tierId, uint256 _price, uint256 _duration, bool _isActive) external {
    //    // if (msg.sender != IERC721(creatorNFT).ownerOf(tokenId)) revert InvalidCaller();
    //    // TODO: Add check via _lzReceive

    //     if (_tierId == 0 || _tierId > tierCount) revert InvalidTier();

    //     SubscriptionTier storage tier = subscriptionTiers[_tierId];
    //     tier.price = _price;
    //     tier.duration = _duration;
    //     tier.isActive = _isActive;

    //     emit TierUpdated(_tierId, _price, _duration, _isActive);
    // }

    function subscribe(uint256 _tierId) public payable {
        if (_tierId == 0 || _tierId > tierCount) revert InvalidTier();
        SubscriptionTier memory tier = subscriptionTiers[_tierId];
        if (!tier.isActive) revert InactiveTier();
        if (msg.value != tier.price) revert InvalidAmount();

        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + tier.duration;

        userSubscriptions[msg.sender] = Subscription(_tierId, startTime, endTime);

        emit SubscriptionCreated(msg.sender, _tierId, startTime, endTime);
    }

    function isSubscribed(address user) external view returns (bool) {
        Subscription memory sub = userSubscriptions[user];
        return sub.endTime > block.timestamp;
    }

    function getSubscriptionDetails(address user) external view returns (uint256, uint256, uint256) {
        Subscription memory sub = userSubscriptions[user];
        return (sub.tierId, sub.startTime, sub.endTime);
    }

    function withdraw() external {
        //  if (msg.sender != IERC721(creatorNFT).ownerOf(tokenId)) revert InvalidCaller();
        // TODO: Add check via _lzReceive

        (bool sent,) = address(msg.sender).call{value: address(this).balance}("");
        if (!sent) revert CannotTransferFunds();
    }

    // IERC165 implementation
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(IERC1271).interfaceId
            || interfaceId == type(IERC6551Account).interfaceId;
    }

    // IERC1271 implementation
    function isValidSignature(bytes32 hash, bytes memory signature) public view override returns (bytes4) {
        address signer = IERC721(creatorNFT).ownerOf(tokenId);
        if (SignatureChecker.isValidSignatureNow(signer, hash, signature)) {
            return IERC1271.isValidSignature.selector;
        } else {
            revert InvalidSignature();
        }
    }

    // IERC6551Account implementation
    function token(address account) internal view returns (uint256, address, uint256) {
        bytes memory encodedData = new bytes(0x60);

        assembly {
            // copy 0x60 bytes from end of context
            extcodecopy(account, add(encodedData, 0x20), 0x4d, 0x60)
        }

        return abi.decode(encodedData, (uint256, address, uint256));
    }

    function token() external view returns (uint256, address, uint256) {
        return token(address(this));
    }

    function isValidSigner(address signer, bytes calldata) public view override returns (bytes4) {
        if (signer == IERC721(creatorNFT).ownerOf(tokenId)) {
            return IERC6551Account.isValidSigner.selector;
        }
        return bytes4(0);
    }

    receive() external payable override {}

    function state() external view override returns (uint256) {}
}
