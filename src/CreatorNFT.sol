// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CreatorNFT is ERC721, Ownable {
    uint256 private _tokenIds;
    mapping(uint256 tokenId => string tokenUri) private tokenUris;
    error OnlyOwner();

    // Mapping from token ID to array of payment model addresses
    mapping(uint256 => address[]) private _paymentModels;

    constructor() ERC721("CreatorNFT", "CNFT") Ownable(msg.sender){}

    function mintCreatorToken(string memory _tokenUri) public returns (uint256) {
        uint256 newTokenId = _tokenIds++;
        _safeMint(msg.sender, newTokenId);
        tokenUris[newTokenId] = _tokenUri;
        return newTokenId;
    }

    function addPaymentModel(uint256 tokenId, address paymentModel) public {
        if(ownerOf(tokenId) != msg.sender) revert OnlyOwner();
        _paymentModels[tokenId].push(paymentModel);
    }

    function getPaymentModels(uint256 tokenId) public view returns (address[] memory) {
        return _paymentModels[tokenId];
    }
}