// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

interface IERC6551Account {
    function token() external view returns (uint256 chainId, address tokenContract, uint256 tokenId);
    function isValidSigner(address signer, bytes calldata) external view returns (bytes4);
}

contract PaymentModel is IERC165, IERC1271, IERC6551Account {
    address public immutable creatorNFT;
    uint256 public immutable tokenId;
    uint256 public subscriptionPrice;
    mapping(address => bool) public subscribers;

    constructor(address _creatorNFT, uint256 _tokenId, uint256 _subscriptionPrice) {
        creatorNFT = _creatorNFT;
        tokenId = _tokenId;
        subscriptionPrice = _subscriptionPrice;
    }

    function subscribe() external payable {
        require(msg.value == subscriptionPrice, "Incorrect payment amount");
        subscribers[msg.sender] = true;
    }

    function isSubscribed(address user) external view returns (bool) {
        return subscribers[user];
    }

    function withdraw() external {
        require(msg.sender == IERC721(creatorNFT).ownerOf(tokenId), "Not the creator");
        payable(msg.sender).transfer(address(this).balance);
    }

    // IERC165 implementation
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return
            interfaceId == type(IERC165).interfaceId ||
            interfaceId == type(IERC1271).interfaceId ||
            interfaceId == type(IERC6551Account).interfaceId;
    }

    // IERC1271 implementation
    function isValidSignature(bytes32 hash, bytes memory signature) public view override returns (bytes4 magicValue) {
        address signer = IERC721(creatorNFT).ownerOf(tokenId);
        if (SignatureChecker.isValidSignatureNow(signer, hash, signature)) {
            return IERC1271.isValidSignature.selector;
        }
        return "";
    }

    // IERC6551Account implementation
    function token() public view override returns (uint256 chainId, address tokenContract, uint256 tokenId_) {
        return (block.chainid, creatorNFT, tokenId);
    }

    function isValidSigner(address signer, bytes calldata) public view override returns (bytes4) {
        if (signer == IERC721(creatorNFT).ownerOf(tokenId)) {
            return IERC6551Account.isValidSigner.selector;
        }
        return "";
    }
}