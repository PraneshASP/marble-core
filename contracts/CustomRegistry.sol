// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { OApp, Origin } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import { ERC6551Registry } from "./vendor/ERC6551Registry.sol";
contract CustomRegistry is ERC6551Registry, OApp {
    constructor(address _endpoint, address _owner) OApp(_endpoint, _owner) Ownable(msg.sender) {}
    
    mapping(bytes32 => address) public paymentModules;

    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    ) internal override {
        address sender = address(uint160(uint256(_origin.sender)));
        (address implementation, bytes32 salt, uint256 chainId, address tokenContract, uint256 tokenId) = 
            abi.decode(_message, (address, bytes32, uint256, address, uint256));
        
        address _account = this.createAccount(implementation, salt, chainId, tokenContract, tokenId);
        paymentModules[keccak256(abi.encode(chainId, tokenId, tokenContract))] = _account;
    }
    function getPaymentModule(uint256 chainId, uint256 tokenId, address tokenContract) public view returns (address) {
        return paymentModules[keccak256(abi.encode(chainId, tokenId, tokenContract))];
    }

}