// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import { IERC6551Account } from "src/interfaces/IERC6551.sol";

/// @notice Pay once, use forever payment model.
/// TODO: This contract should be inherting LZ OAPP interface and subscribe logic should call LZ Endpoint to enable cross-chain subscriptions
/// TODO: Look into integrating SIGN PROTOCOL to attest subscriptions rather than paying for gas (GASLESS SUBSCRIPTION) ?????
contract POUFPaymentModel is IERC165, IERC1271, IERC6551Account {
    address public creatorNFT;
    uint256 public tokenId;
    uint256 public subscriptionPrice;

    bool isInitialized;

    mapping(address => bool) public subscribers;

    error Initialized();
    error InvalidAmount();
    error InvalidCaller();
    error AlreadySubscribed();
    error CannotTransferFunds();
    error InvalidSignature();

    function initialize(address _creatorNFT, uint256 _tokenId, uint256 _subscriptionPrice) external {
        if (isInitialized) revert Initialized();

        creatorNFT = _creatorNFT;
        tokenId = _tokenId;
        subscriptionPrice = _subscriptionPrice;

        isInitialized = true;
    }

    function subscribe() public payable {
        if (msg.value != subscriptionPrice) revert InvalidAmount();
        if (subscribers[msg.sender] == true) revert AlreadySubscribed();
        subscribers[msg.sender] = true;
    }

    function isSubscribed(address user) external view returns (bool) {
        return subscribers[user];
    }

    function withdraw() external {
        if (msg.sender != IERC721(creatorNFT).ownerOf(tokenId)) revert InvalidCaller();
        (bool sent,) = address(msg.sender).call{ value: address(this).balance }("");
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
    function token() public view override returns (uint256 chainId, address tokenContract, uint256 tokenId_) {
        return (block.chainid, creatorNFT, tokenId);
    }

    function isValidSigner(address signer, bytes calldata) public view override returns (bytes4) {
        if (signer == IERC721(creatorNFT).ownerOf(tokenId)) {
            return IERC6551Account.isValidSigner.selector;
        }
    }

    receive() external payable override { }

    function state() external view override returns (uint256) { }
}
