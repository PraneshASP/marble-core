// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import { IERC6551Registry } from "src/interfaces/IERC6551Registry.sol";
import { ILayerZeroEndpointV2, MessagingFee } from "@layerzerolabs/lz-evm-protocol-v2//contracts/interfaces/ILayerZeroEndpointV2.sol";

interface ILayerZeroV2Executor {
    function quote(uint32 _dstEid, bytes calldata _message, bytes calldata _options) external view returns (MessagingFee memory);
    function execute(uint32 _dstEid, bytes calldata _message, bytes calldata _options) external payable;
}

library MsgCodec {
    function encode(address sender, bytes calldata payload) internal pure returns (bytes memory) {
        return abi.encode(sender, payload);
    }

    function decode(bytes calldata message)
        internal
        pure
        returns (address sender, bytes memory payload)
    {
        return abi.decode(message, (address, bytes));
    }
}

contract CreatorNFT is ERC721, Ownable {
    uint256 private _tokenIds;
    mapping(uint256 tokenId => string tokenUri) private tokenUris;

    // Mapping from tokenId to chainId to PaymentModule address
    mapping(uint256 => mapping(uint256 => address)) public paymentModules;

    IERC6551Registry immutable registry;
    ILayerZeroV2Executor immutable lzExecutor;
    address immutable paymentModuleImplementation;

    event PaymentModuleDeployed(uint256 indexed tokenId, uint256 chainId, address paymentModule);

    constructor(
        address _registry,
        address _lzExecutor,
        address _paymentModuleImplementation
    ) 
        ERC721("CreatorNFT", "CNFT") 
        Ownable(msg.sender) 
    {
        registry = IERC6551Registry(_registry);
        lzExecutor = ILayerZeroV2Executor(_lzExecutor);
        paymentModuleImplementation = _paymentModuleImplementation;
    }

    function mint(string memory _tokenUri) public returns (uint256) {
        uint256 newTokenId = _tokenIds++;
        _safeMint(msg.sender, newTokenId);
        tokenUris[newTokenId] = _tokenUri;
        _deployPaymentModule(newTokenId, uint32(block.chainid), address(0));
        return newTokenId;
    }
    function deployPaymentModule(uint256 tokenId, uint32 destinationChainId, address paymentModuleAddress) external payable {
        require(ownerOf(tokenId) == msg.sender, "Not token owner");
        _deployPaymentModule(tokenId, destinationChainId, paymentModuleAddress);
    }

    function _deployPaymentModule(uint256 tokenId, uint32 destinationChainId, address paymentModuleAddress) internal {
        bytes32 salt = keccak256(abi.encode(address(this), tokenId, destinationChainId));
        
        if (destinationChainId == block.chainid) {
            address paymentModule = registry.createAccount(
                paymentModuleImplementation,
                salt,
                destinationChainId,
                address(this),
                tokenId
            );
            paymentModules[tokenId][destinationChainId] = paymentModule;
            emit PaymentModuleDeployed(tokenId, destinationChainId, paymentModule);
        } else {
            require(paymentModuleAddress != address(0), "Payment module address required for cross-chain deployment");
            
             bytes memory createAccountParams = abi.encode(
                paymentModuleAddress,  // implementation
                salt,
                destinationChainId,
                address(this),  // tokenContract
                tokenId
            );

             bytes memory payload = abi.encode(
                address(registry),   
                abi.encodeWithSignature("createAccount(address,bytes32,uint256,address,uint256)", createAccountParams),
                block.chainid   
            );

            bytes memory options = "";  

             MessagingFee memory fee = lzExecutor.quote(destinationChainId, payload, options);
            require(msg.value >= fee.nativeFee, "Insufficient fee");

            // Execute the cross-chain call
            lzExecutor.execute{value: fee.nativeFee}(destinationChainId, payload, options);
            
            // Note: We don't know the exact address of the deployed PaymentModule on the destination chain
            // We'll need to implement a callback mechanism to update this
            emit PaymentModuleDeployed(tokenId, destinationChainId, address(0));
        }
    }
}