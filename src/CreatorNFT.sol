// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import { IPOUFPaymentModel } from "src/interfaces/IPOUFPaymentModel.sol";
import { IERC6551Registry } from "src/interfaces/IERC6551Registry.sol";

contract CreatorNFT is ERC721, Ownable {
    uint256 private _tokenIds;
    mapping(uint256 tokenId => string tokenUri) private tokenUris;

    error OnlyOwner();

    // Mapping from token ID to array of payment model addresses
    mapping(uint256 => address[]) private _paymentModels;

    IPOUFPaymentModel immutable poufPaymentModelImpl; // TODO: revisit appraoch to make it permissioless
    IERC6551Registry immutable registry;

    constructor(address _poufPaymentModelImpl, address _registry) ERC721("CreatorNFT", "CNFT") Ownable(msg.sender) {
        poufPaymentModelImpl = IPOUFPaymentModel(_poufPaymentModelImpl);
        registry = IERC6551Registry(_registry);
    }

    function mint(string memory _tokenUri) public returns (uint256) {
        uint256 newTokenId = _tokenIds++;
        _safeMint(msg.sender, newTokenId);
        tokenUris[newTokenId] = _tokenUri;
        return newTokenId;
    }

    function deployPOUFPaymentModel(uint256 tokenId, uint256 subscriptionPrice) public {
        if (ownerOf(tokenId) != msg.sender) revert OnlyOwner();
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        address paymentModel = registry.createAccount(
            address(poufPaymentModelImpl),
            keccak256(abi.encode(msg.sender, tokenId, subscriptionPrice)),
            chainId,
            address(this),
            tokenId
        );
        IPOUFPaymentModel(paymentModel).initialize(address(this), tokenId, subscriptionPrice);
        _paymentModels[tokenId].push(paymentModel);
    }

    function getPaymentModels(uint256 tokenId) public view returns (address[] memory) {
        return _paymentModels[tokenId];
    }
}
