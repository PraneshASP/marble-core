// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {OApp, MessagingFee, Origin} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {MessagingReceipt} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";
import {IERC6551Registry} from "./interfaces/IERC6551Registry.sol";
import {AddressCast} from "@layerzerolabs/lz-evm-protocol-v2/contracts/libs/AddressCast.sol";

contract CreatorNFT is ERC721, Ownable, OApp {
    uint256 private _tokenIds;
    mapping(uint256 => string) private _tokenUris;

    // Mapping from tokenId to chainId to PaymentModule address
    mapping(uint256 => mapping(uint256 => address)) public paymentModules;

    IERC6551Registry immutable registry;
    address immutable paymentModuleImplementation;

    uint16 public constant DEPLOY_PAYMENT_MODULE = 1;

    event PaymentModuleDeployed(uint256 indexed tokenId, uint256 chainId, address paymentModule);

    constructor(address _endpoint, address _delegate, address _registry, address _paymentModuleImplementation)
        ERC721("CreatorNFT", "CNFT")
        Ownable(_delegate)
        OApp(_endpoint, _delegate)
    {
        registry = IERC6551Registry(_registry);
        paymentModuleImplementation = _paymentModuleImplementation;
    }

    function mint(string memory _tokenUri) public returns (uint256) {
        uint256 newTokenId = _tokenIds++;
        _safeMint(msg.sender, newTokenId);
        _tokenUris[newTokenId] = _tokenUri;
        _deployPaymentModule(newTokenId, uint32(block.chainid), address(0));
        return newTokenId;
    }

    function deployPaymentModule(uint256 tokenId, uint32 destinationChainId, address paymentModuleAddress)
        external
        payable
    {
        require(ownerOf(tokenId) == msg.sender, "Not token owner");
        _deployPaymentModule(tokenId, destinationChainId, paymentModuleAddress);
    }

    function _deployPaymentModule(uint256 tokenId, uint32 destinationChainId, address paymentModuleAddress) internal {
        bytes32 salt = keccak256(abi.encode(address(this), tokenId, destinationChainId));

        if (destinationChainId == block.chainid) {
            address paymentModule =
                registry.createAccount(paymentModuleImplementation, salt, destinationChainId, address(this), tokenId);
            paymentModules[tokenId][destinationChainId] = paymentModule;
            emit PaymentModuleDeployed(tokenId, destinationChainId, paymentModule);
        } else {
            require(paymentModuleAddress != address(0), "Payment module address required for cross-chain deployment");

            bytes memory payload = abi.encode(paymentModuleAddress, salt, destinationChainId, address(this), tokenId);

            _lzSend(
                destinationChainId,
                payload,
                abi.encodePacked(uint16(1), uint256(200000)), // Default options
                MessagingFee(msg.value, 0),
                payable(msg.sender)
            );

            emit PaymentModuleDeployed(tokenId, destinationChainId, address(0));
        }
    }

    function send(uint32 _dstEid, string memory _message, bytes calldata _options)
        external
        payable
        returns (MessagingReceipt memory receipt)
    {
        bytes memory payload = abi.encode(_message);
        receipt = _lzSend(_dstEid, payload, _options, MessagingFee(msg.value, 0), payable(msg.sender));
    }

    function quote(
        uint32 _dstEid,
        string memory _message,
        bytes memory _options,
        bool //_payInLzToken
    ) public view returns (MessagingFee memory fee) {
        bytes memory payload = abi.encode(_message);
        fee = _quote(_dstEid, payload, _options, false);
    }

    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    ) internal virtual override {}

    // CreatorNFT.sol

    function getDeploymentFees(uint256 tokenId, uint32 destinationChainId, address paymentModuleAddress)
        public
        view
        returns (uint256 nativeFee, uint256 zroFee)
    {
        //require(ownerOf(tokenId) == msg.sender, "Not token owner");
        require(destinationChainId != uint32(block.chainid), "Use local deployment for same chain");
        require(paymentModuleAddress != address(0), "Payment module address required for cross-chain deployment");

        bytes32 salt = keccak256(abi.encode(address(this), tokenId, destinationChainId));

        bytes memory payload = abi.encode(paymentModuleAddress, salt, destinationChainId, address(this), tokenId);

        MessagingFee memory fee =
            _quote(destinationChainId, payload, abi.encodePacked(uint16(1), uint256(200000)), false);

        return (fee.nativeFee, fee.lzTokenFee);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    // function _getPeerOrRevert(uint32 eid) internal view override returns (bytes32) {
    //     if (peers[eid] != bytes32(0)) return peers[eid];
    //     return AddressCast.toBytes32(address(this));
    // }
}
