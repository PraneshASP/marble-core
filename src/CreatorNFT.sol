// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import { IPaymentModel } from "src/interfaces/IPaymentModel.sol";
import { IERC6551Registry } from "src/interfaces/IERC6551Registry.sol";

contract CreatorNFT is ERC721, Ownable {
    uint256 private _tokenIds;
    mapping(uint256 tokenId => string tokenUri) private tokenUris;

    error OnlyOwner();
    error InvalidPaymentModel();
    error NoValidSubscription();
    error OnlyPaymentModel();

    // Mapping from token ID to array of payment model addresses
    mapping(uint256 => address[]) private _paymentModels;

    // Mapping to track valid payment models
    mapping(address => bool) public isValidPaymentModel;

    struct SubscriptionDetails {
        address paymentModel;
        uint256 tierId;
        uint256 startTime;
        uint256 endTime;
    }

    IPaymentModel immutable paymentModelImpl;
    IERC6551Registry immutable registry;

    mapping(uint256 => mapping(address => mapping(address => SubscriptionDetails))) private _subscriptions;

    event PaymentModelDeployed(uint256 indexed tokenId, address paymentModel);
    event SubscriptionUpdated(
        uint256 indexed tokenId,
        address indexed paymentModel,
        address indexed subscriber,
        uint256 tierId,
        uint256 startTime,
        uint256 endTime
    );

    constructor(address _paymentModelImpl, address _registry) ERC721("CreatorNFT", "CNFT") Ownable(msg.sender) {
        paymentModelImpl = IPaymentModel(_paymentModelImpl);
        registry = IERC6551Registry(_registry);
    }

    function mint(string memory _tokenUri) public returns (uint256) {
        uint256 newTokenId = _tokenIds++;
        _safeMint(msg.sender, newTokenId);
        tokenUris[newTokenId] = _tokenUri;
        _deployPaymentModel(newTokenId);
        return newTokenId;
    }

    function _deployPaymentModel(uint256 tokenId) internal {
        if (ownerOf(tokenId) != msg.sender) revert OnlyOwner();
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        address paymentModel = registry.createAccount(
            address(paymentModelImpl), keccak256(abi.encode(msg.sender, tokenId)), chainId, address(this), tokenId
        );
        IPaymentModel(paymentModel).initialize(address(this), tokenId);
        _paymentModels[tokenId].push(paymentModel);
        isValidPaymentModel[paymentModel] = true;
        emit PaymentModelDeployed(tokenId, paymentModel);
    }

    function getPaymentModels(uint256 tokenId) public view returns (address[] memory) {
        return _paymentModels[tokenId];
    }

    function updateSubscription(
        uint256 tokenId,
        address paymentModel,
        address subscriber,
        uint256 tierId,
        uint256 startTime,
        uint256 endTime
    )
        external
    {
        if (!isValidPaymentModel[paymentModel]) revert InvalidPaymentModel();
        if (msg.sender != paymentModel) revert OnlyPaymentModel();
        _subscriptions[tokenId][paymentModel][subscriber] = SubscriptionDetails(msg.sender, tierId, startTime, endTime);

        emit SubscriptionUpdated(tokenId, paymentModel, subscriber, tierId, startTime, endTime);
    }

    function getSubscriptionDetails(uint256 tokenId, address user) public view returns (SubscriptionDetails memory) {
        address[] memory models = _paymentModels[tokenId];
        for (uint256 i = 0; i < models.length; i++) {
            IPaymentModel paymentModel = IPaymentModel(models[i]);
            (uint256 tierId, uint256 startTime, uint256 endTime) = paymentModel.getSubscriptionDetails(user);
            if (endTime > block.timestamp) {
                return SubscriptionDetails(address(paymentModel), tierId, startTime, endTime);
            }
        }
        revert NoValidSubscription();
    }

    function isSubscribed(uint256 tokenId, address user) public view returns (bool) {
        address[] memory models = _paymentModels[tokenId];
        for (uint256 i = 0; i < models.length; i++) {
            if (IPaymentModel(models[i]).isSubscribed(user)) {
                return true;
            }
        }
        return false;
    }
}
